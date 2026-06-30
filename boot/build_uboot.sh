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
# U-Boot's *own* control DTB decides which UART its console lands on (via
# /chosen/stdout-path -> the serialN alias).  xilinx_zynqmp_virt_defconfig is
# CONFIG_OF_SEPARATE + CONFIG_OF_BOARD: with our FSBL boot chain nothing hands
# U-Boot a DTB at runtime, so it uses the one built into u-boot.elf.  An
# in-tree eval-board DT (k26 -> serial1, zcu100/zcu102, ...) does NOT match this
# board's serial map, so U-Boot prints to the wrong PS UART and looks hung.
#
# Faithful approach (same as the factory PetaLinux build): feed U-Boot the
# board's OWN device tree as its control DTB, so its serial aliases match the
# kernel's exactly (serial0 = PS UART0 = the USB-UART console).  EXT_DTB
# overrides the appended/embedded DTB; the board DTB is produced by the
# preceding `make devicetree` step (board/device-tree/system-user.dtsi pins the
# serial0..3 aliases to match board/hw-handoff, see gen_devicetree.sh).
UBOOT_EXT_DTB="${UBOOT_EXT_DTB:-$OUT_DIR/system.dtb}"
[ -r "$UBOOT_EXT_DTB" ] || die "board DTB not found: $UBOOT_EXT_DTB - run 'make devicetree' before 'make boot'"
log "U-Boot control DTB (EXT_DTB) = $UBOOT_EXT_DTB"
make -C "$UB" -j"$(nproc)" \
     BL31="${OUT_DIR}/bl31.elf" \
     EXT_DTB="$UBOOT_EXT_DTB" || \
make -C "$UB" -j"$(nproc)" EXT_DTB="$UBOOT_EXT_DTB" u-boot.elf   # fallback: just the ELF

cp "$UB/u-boot.elf" "$OUT_DIR/u-boot.elf"
log "U-Boot -> $OUT_DIR/u-boot.elf"

log "Compiling boot.scr from boot/boot.cmd"
mkimage -c none -A arm64 -T script -d "$HERE/boot.cmd" "$OUT_DIR/boot.scr"
log "boot.scr -> $OUT_DIR/boot.scr"
