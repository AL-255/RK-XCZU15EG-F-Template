#!/usr/bin/env bash
#
# build_rootfs.sh - build an apt-capable arm64 root filesystem for RK-XCZU15EG-F.
#
# Uses mmdebstrap in --mode=unshare so NO root is required (relies on
# unprivileged user namespaces + the qemu-aarch64 binfmt handler).  Produces a
# real Debian (default) or Ubuntu system: `apt install ...` works on the board.
#
# Configure via env (see scripts/env.sh):
#   ROOTFS_DISTRO=debian|ubuntu  ROOTFS_SUITE=bookworm|noble|...
#   ROOTFS_HOSTNAME  ROOTFS_USER  ROOTFS_PASS  ROOTFS_ROOTPASS
#
# Output: $OUT_DIR/rootfs.tar.zst    (archive with correct uid0 ownership,
#                                     consumed by image/make_sdcard.sh)
#
# Note: --mode=unshare also creates a MOUNT namespace, so mmdebstrap builds in
# TMPDIR and streams a tarball out (the final OUT_DIR may live on a secondary
# mount that is invisible inside that namespace).  Point TMPDIR at a roomy
# directory ON THE ROOT FILESYSTEM if your build dir is on another disk.
#
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "$HERE/../scripts/env.sh"

command -v mmdebstrap >/dev/null || die "mmdebstrap missing - apt-get install mmdebstrap"
[ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ] || \
    die "qemu-aarch64 binfmt not registered - apt-get install qemu-user-binfmt binfmt-support"

OVERLAY="$HERE/overlay"
# mmdebstrap builds here (must be on a filesystem visible inside its mount ns,
# i.e. the root fs).  Default to a roomy root-fs scratch dir; override TMPDIR.
export TMPDIR="${ROOTFS_TMPDIR:-${TMPDIR:-/var/tmp}}"
mkdir -p "$TMPDIR" 2>/dev/null || true

# --- distro specifics --------------------------------------------------------
case "$ROOTFS_DISTRO" in
  debian)
    MIRROR="${ROOTFS_MIRROR:-http://deb.debian.org/debian}"
    COMPONENTS="main,contrib,non-free-firmware"
    KEYRING_PKG="debian-archive-keyring" ;;
  ubuntu)
    # Ubuntu arm64 lives on the ports mirror.
    MIRROR="${ROOTFS_MIRROR:-http://ports.ubuntu.com/ubuntu-ports}"
    COMPONENTS="main,universe,restricted,multiverse"
    KEYRING_PKG="ubuntu-keyring" ;;
  *) die "ROOTFS_DISTRO must be debian or ubuntu (got '$ROOTFS_DISTRO')" ;;
esac

# --- archive keyring (mmdebstrap verifies the release on the HOST) -----------
# Use the host keyring if installed; otherwise fetch the keyring .deb locally so
# the build is self-contained and needs no extra host packages.
resolve_keyring() {
    # mmdebstrap's apt (inside the unshare MOUNT namespace) must be able to read
    # the keyring, so it has to live on the ROOT filesystem - we stage it under
    # TMPDIR, which is guaranteed mount-ns-visible.  Never reference a build dir
    # that may sit on a separate mount.
    local name="$1" pkg="$2" host="/usr/share/keyrings/$1"
    local dst="$TMPDIR/keyrings/$name"
    mkdir -p "$TMPDIR/keyrings"
    if [ -r "$dst" ]; then echo "$dst"; return; fi
    if [ -r "$host" ]; then cp -f "$host" "$dst"; echo "$dst"; return; fi
    local work; work="$(mktemp -d "$TMPDIR/kr.XXXXXX")"
    ( cd "$work"
        local rel
        rel=$(curl -fsSL "$MIRROR/dists/$ROOTFS_SUITE/main/binary-amd64/Packages.gz" \
            | zcat | awk -v p="$pkg" '$0=="Package: "p{f=1} f&&/^Filename:/{print $2; exit}')
        curl -fsSL -o k.deb "$MIRROR/$rel" && ar x k.deb && tar xf data.tar.* )
    cp -f "$work/usr/share/keyrings/$name" "$dst"
    rm -rf "$work"
    echo "$dst"
}
case "$ROOTFS_DISTRO" in
  debian) KEYRING=$(resolve_keyring debian-archive-keyring.gpg debian-archive-keyring "") ;;
  ubuntu) KEYRING=$(resolve_keyring ubuntu-archive-keyring.gpg ubuntu-keyring "") ;;
esac
[ -r "$KEYRING" ] || die "could not obtain archive keyring for $ROOTFS_DISTRO"
log "using archive keyring: $KEYRING"

# --- package set -------------------------------------------------------------
PKGS="openssh-server,sudo,ifupdown,isc-dhcp-client,iproute2,iputils-ping,"
PKGS+="netbase,ca-certificates,locales,less,nano,vim-tiny,bash-completion,"
PKGS+="systemd-sysv,udev,kmod,dbus,htop,curl,wget,rsync,usbutils,pciutils,"
PKGS+="i2c-tools,can-utils,ethtool,gpiod,device-tree-compiler,python3,"
PKGS+="e2fsprogs,parted,file,$KEYRING_PKG"

log "Building $ROOTFS_DISTRO/$ROOTFS_SUITE arm64 rootfs (TMPDIR=$TMPDIR)"

# mmdebstrap customize-hooks run INSIDE the unshare mount namespace, so the
# overlay + configure script must be staged on the ROOT filesystem (under
# TMPDIR), not on a build dir that may live on a separate mount.
STAGE="$TMPDIR/stage"; rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -a "$OVERLAY" "$STAGE/overlay"

# Generated in-chroot configuration script (values baked in).
CONF="$STAGE/configure.sh"
cat > "$CONF" <<EOF
#!/bin/sh
set -e
# apply the file overlay copied in at /tmp/overlay, then make the installed
# system files root-owned (the host staging copy carried the builder's uid).
cp -a /tmp/overlay/. /
chown -R 0:0 /etc/fstab /etc/network /etc/systemd/network /etc/systemd/system \
             /usr/local/bin /usr/local/sbin 2>/dev/null || true
rm -rf /tmp/overlay

echo "$ROOTFS_HOSTNAME" > /etc/hostname
printf '127.0.0.1\tlocalhost\n127.0.1.1\t%s\n' "$ROOTFS_HOSTNAME" > /etc/hosts

# passwords + sudo user
echo "root:$ROOTFS_ROOTPASS" | chpasswd
id "$ROOTFS_USER" 2>/dev/null || useradd -m -s /bin/bash -G sudo "$ROOTFS_USER"
echo "$ROOTFS_USER:$ROOTFS_PASS" | chpasswd

# SSH: allow password login out of the box (lab/dev board)
mkdir -p /etc/ssh/sshd_config.d
printf 'PermitRootLogin yes\nPasswordAuthentication yes\n' > /etc/ssh/sshd_config.d/10-rk.conf
systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true

# serial console on the PS UART0
systemctl enable serial-getty@ttyPS0.service 2>/dev/null || true

# networking: DHCP on whatever the kernel calls the GEM3 port (end0/eth0)
systemctl enable systemd-networkd 2>/dev/null || true

# locales
sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen 2>/dev/null || true
locale-gen 2>/dev/null || true

# first-boot rootfs expansion + fpga firmware dir + boot mountpoint
systemctl enable rk-firstboot.service 2>/dev/null || true
mkdir -p /lib/firmware /boot/firmware
# make sure the load-bitstream helper and first-boot script are executable
chmod 0755 /usr/local/bin/load-bitstream.sh /usr/local/sbin/rk-firstboot.sh 2>/dev/null || true
rm -f /tmp/configure.sh
EOF
chmod +x "$CONF"

# --- run mmdebstrap (stream a tarball out; built inside TMPDIR) ---------------
log "Running mmdebstrap -> $OUT_DIR/rootfs.tar.zst"
mmdebstrap \
    --mode=unshare \
    --architectures=arm64 \
    --variant=minbase \
    --format=tar \
    --keyring="$KEYRING" \
    --components="$COMPONENTS" \
    --include="$PKGS" \
    --customize-hook="copy-in $STAGE/overlay /tmp" \
    --customize-hook="copy-in $CONF /tmp" \
    --customize-hook='chroot "$1" /tmp/configure.sh' \
    "$ROOTFS_SUITE" - "$MIRROR" | zstd -q -10 -T0 -o "$OUT_DIR/rootfs.tar.zst" -f

log "Rootfs archive: $OUT_DIR/rootfs.tar.zst ($(du -h "$OUT_DIR/rootfs.tar.zst" | cut -f1))"
