#!/usr/bin/env bash
#
# make_boot_bin.sh - assemble BOOT.BIN with bootgen from the boot-chain ELFs.
#
# Order (ZynqMP):  FSBL -> PMUFW -> BL31 (ATF) -> U-Boot.
#
# By DEFAULT no bitstream is embedded: the PL is left UNCONFIGURED at power-up
# and is programmed later from Linux (the PS side) via the FPGA manager - which
# is exactly the workflow this template is built around.  Pass a .bit path as
# $1 (or set BITSTREAM=...) if you want the PL pre-loaded by the FSBL instead.
#
# Output: $OUT_DIR/BOOT.BIN
#
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../scripts/env.sh" --with-xilinx

command -v bootgen >/dev/null || die "bootgen not found - source Vitis/Vivado settings64.sh"
for f in fsbl.elf pmufw.elf bl31.elf u-boot.elf; do
    [ -r "$OUT_DIR/$f" ] || die "missing $OUT_DIR/$f - build the boot chain first"
done

BITSTREAM="${1:-${BITSTREAM:-}}"
BIF="$BUILD_DIR/boot.bif"

{
    echo "the_ROM_image:"
    echo "{"
    echo "    [bootloader, destination_cpu=a53-0] $OUT_DIR/fsbl.elf"
    echo "    [pmufw_image] $OUT_DIR/pmufw.elf"
    if [ -n "$BITSTREAM" ]; then
        [ -r "$BITSTREAM" ] || die "bitstream not readable: $BITSTREAM"
        echo "    [destination_device=pl] $BITSTREAM"
    fi
    echo "    [destination_cpu=a53-0, exception_level=el-3, trustzone] $OUT_DIR/bl31.elf"
    echo "    [destination_cpu=a53-0, exception_level=el-2] $OUT_DIR/u-boot.elf"
    echo "}"
} > "$BIF"

log "bootgen BIF:"; sed 's/^/    /' "$BIF"
bootgen -image "$BIF" -arch zynqmp -w -o "$OUT_DIR/BOOT.BIN"
log "BOOT.BIN -> $OUT_DIR/BOOT.BIN  ($(du -h "$OUT_DIR/BOOT.BIN" | cut -f1))"
[ -z "$BITSTREAM" ] && log "PL left unconfigured - program it from Linux (see docs/04-bitstream-from-ps.md)"
