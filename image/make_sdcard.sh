#!/usr/bin/env bash
#
# make_sdcard.sh - assemble a bootable micro-SD image for RK-XCZU15EG-F.
#
# Layout (MBR):
#   p1  FAT32  "BOOT"  -> BOOT.BIN, Image, system.dtb, boot.scr
#   p2  ext4   "rootfs"-> the Debian/Ubuntu root filesystem (+ kernel modules)
#
# Fully ROOTLESS:
#   * FAT  built with mtools  (mformat / mcopy)
#   * ext4 built with mke2fs -d inside a user namespace, where the rootfs
#     tarball is extracted so that file ownership (root vs the user) is
#     recorded correctly without sudo.
#
# Output: $OUT_DIR/sdcard.img   (flash with: dd if=sdcard.img of=/dev/sdX bs=4M)
#
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "$HERE/../scripts/env.sh"

BOOT_MB="${BOOT_MB:-512}"
ROOTFS_TAR="${ROOTFS_TAR:-$OUT_DIR/rootfs.tar.zst}"
MODULES_TAR="${MODULES_TAR:-$OUT_DIR/modules.tar.zst}"
IMG="$OUT_DIR/sdcard.img"

for f in BOOT.BIN Image system.dtb boot.scr; do
    [ -r "$OUT_DIR/$f" ] || die "missing $OUT_DIR/$f - build boot+kernel+dtb first"
done
[ -r "$ROOTFS_TAR" ] || die "rootfs archive not found: $ROOTFS_TAR (run rootfs/build_rootfs.sh)"
command -v mformat >/dev/null || die "mtools missing - apt-get install mtools"

# --- FAT boot partition ------------------------------------------------------
BOOTIMG="$BUILD_DIR/boot.fat"
rm -f "$BOOTIMG"
truncate -s "${BOOT_MB}M" "$BOOTIMG"
mformat -i "$BOOTIMG" -F -v BOOT ::
for f in BOOT.BIN Image system.dtb boot.scr; do mcopy -i "$BOOTIMG" "$OUT_DIR/$f" "::/$f"; done
log "FAT boot partition built ($BOOTIMG)"

# --- ext4 root partition (rootless, correct ownership) -----------------------
ROOTIMG="$BUILD_DIR/root.ext4"
# Estimate size from the uncompressed tar, then build with ~1.2 GB head-room.
RFS_KB=$(( $(zstd -dc "$ROOTFS_TAR" | wc -c) / 1024 ))
ROOT_MB=$(( RFS_KB / 1024 + 1300 ))
log "rootfs ~${RFS_KB}KiB  -> ext4 ${ROOT_MB}MiB"
rm -f "$ROOTIMG"; truncate -s "${ROOT_MB}M" "$ROOTIMG"

cat > "$BUILD_DIR/_mkroot.sh" <<MK
#!/bin/bash
set -e
WD="\$(mktemp -d "${BUILD_DIR}/rootfs.XXXXXX")"
trap 'rm -rf "\$WD"' EXIT
# Extract the rootfs first (creates the usrmerge /lib -> usr/lib symlink).
# Skip the static /dev nodes: mknod is not permitted in a user namespace and
# the kernel's devtmpfs recreates them at boot anyway.  mke2fs -d will still
# leave an empty /dev mount point.
zstd -dc "$ROOTFS_TAR" | tar -C "\$WD" --numeric-owner --exclude='./dev/*' -xf -
# Then the modules: --keep-directory-symlink follows /lib so the modules land
# in usr/lib/modules instead of clobbering the symlink.
[ -r "$MODULES_TAR" ] && zstd -dc "$MODULES_TAR" | tar -C "\$WD" --numeric-owner --keep-directory-symlink -xf - || true
mke2fs -q -t ext4 -L rootfs -d "\$WD" "$ROOTIMG"
MK
chmod +x "$BUILD_DIR/_mkroot.sh"

# Build the ext4 with correct ownership.  Preferred: a user namespace that maps
# our subuid/subgid ranges (rootless).  If that is unavailable, fall back to
# running directly (correct only when already root).
if [ "$(id -u)" = 0 ]; then
    bash "$BUILD_DIR/_mkroot.sh"
    log "ext4 root built as root"
elif unshare --user --map-auto --map-root-user bash "$BUILD_DIR/_mkroot.sh"; then
    log "ext4 root built inside user namespace (ownership preserved)"
else
    die "could not build ext4 rootlessly - install 'uidmap' (subuid/subgid ranges) or run this step as root"
fi
log "ext4 root partition built ($ROOTIMG)"

# --- container image + MBR partition table -----------------------------------
TOTAL_MB=$(( 1 + BOOT_MB + ROOT_MB ))
rm -f "$IMG"; truncate -s "${TOTAL_MB}M" "$IMG"
sfdisk "$IMG" <<SFDISK
label: dos
unit: sectors
start=2048, size=$(( BOOT_MB * 2048 )), type=c, bootable
start=$(( 2048 + BOOT_MB * 2048 )), type=83
SFDISK

dd if="$BOOTIMG" of="$IMG" bs=1M seek=1                  conv=notrunc status=none
dd if="$ROOTIMG" of="$IMG" bs=1M seek=$(( 1 + BOOT_MB )) conv=notrunc status=none

log "SD card image -> $IMG ($(du -h "$IMG" | cut -f1))"
echo "   flash with:  sudo dd if=$IMG of=/dev/sdX bs=4M conv=fsync status=progress"
echo "   boot DIP (ON=0):  SD = 4321->0101"
