#!/usr/bin/env bash
#
# build_uboot.sh - build U-Boot for ZynqMP and compile the boot script.
#
# We use xilinx_zynqmp_virt_defconfig: a generic ZynqMP U-Boot that only needs
# to bring up the SD controller, then hand off to the distro boot flow which
# loads Image + system.dtb + boot.scr from the FAT boot partition.  The KERNEL
# receives our full board device tree (system.dtb), so U-Boot's own DT only has
# to be "good enough to read the SD card" - which the generic config already is.
#
# Output: $OUT_DIR/u-boot.elf  $OUT_DIR/boot.scr
#
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "$HERE/../scripts/env.sh"

UB="${UBOOT_SRC:-$SRC_DIR/u-boot}"
[ -d "$UB" ] || die "U-Boot source missing - run scripts/fetch_sources.sh"
command -v mkimage >/dev/null || die "mkimage missing - apt-get install u-boot-tools"

export CROSS_COMPILE ARCH=arm
log "Configuring U-Boot (xilinx_zynqmp_virt_defconfig)"
make -C "$UB" xilinx_zynqmp_virt_defconfig

log "Building U-Boot"
# Pass BL31 so binman's optional flash.bin/itb step is satisfied; the artefact
# we actually consume is u-boot.elf, combined with BL31 by bootgen later.
make -C "$UB" -j"$(nproc)" \
     BL31="${OUT_DIR}/bl31.elf" \
     DEVICE_TREE="${UBOOT_DEVICE_TREE:-zynqmp-sm-k26-revA}" || \
make -C "$UB" -j"$(nproc)" u-boot.elf      # fallback: just the ELF we need

cp "$UB/u-boot.elf" "$OUT_DIR/u-boot.elf"
log "U-Boot -> $OUT_DIR/u-boot.elf"

log "Compiling boot.scr from boot/boot.cmd"
mkimage -c none -A arm64 -T script -d "$HERE/boot.cmd" "$OUT_DIR/boot.scr"
log "boot.scr -> $OUT_DIR/boot.scr"
