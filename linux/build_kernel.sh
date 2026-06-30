#!/usr/bin/env bash
#
# build_kernel.sh - build the arm64 Linux kernel (linux-xlnx) for RK-XCZU15EG-F.
# Starts from xilinx_zynqmp_defconfig and merges linux/config/rk-xczu15eg-f.cfg
# to guarantee the FPGA manager / device-tree-overlay / RTL8211F drivers needed
# by this board and by PS-side bitstream loading.
#
# Output: $OUT_DIR/Image                 (flat kernel image for U-Boot booti)
#         $OUT_DIR/modules.tar.zst       (modules tree, overlaid into the rootfs)
#
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "$HERE/../scripts/env.sh"

LX="${LINUX_SRC:-$SRC_DIR/linux}"
[ -d "$LX" ] || die "linux source missing - run scripts/fetch_sources.sh"
export ARCH CROSS_COMPILE
JOBS="$(nproc)"

KDEFCONFIG="${KDEFCONFIG:-xilinx_defconfig}"
log "Configuring kernel ($KDEFCONFIG + board fragment)"
# tolerate the historical name on older trees
make -C "$LX" "$KDEFCONFIG" 2>/dev/null || make -C "$LX" xilinx_zynqmp_defconfig 2>/dev/null || make -C "$LX" defconfig
"$LX/scripts/kconfig/merge_config.sh" -m -O "$LX" \
    "$LX/.config" "$HERE/config/rk-xczu15eg-f.cfg"
make -C "$LX" olddefconfig

log "Building Image + modules (-j$JOBS)"
make -C "$LX" -j"$JOBS" Image modules

cp "$LX/arch/arm64/boot/Image" "$OUT_DIR/Image"
log "Image -> $OUT_DIR/Image"

MODT="$BUILD_DIR/modules"
rm -rf "$MODT"; mkdir -p "$MODT"
make -C "$LX" -j"$JOBS" INSTALL_MOD_PATH="$MODT" modules_install
# strip the build/source symlinks that point at the host tree
find "$MODT/lib/modules" -maxdepth 2 \( -name build -o -name source \) -type l -delete 2>/dev/null || true
tar --numeric-owner -C "$MODT" -cf - . | zstd -q -19 -T0 -o "$OUT_DIR/modules.tar.zst" -f
log "modules -> $OUT_DIR/modules.tar.zst"
