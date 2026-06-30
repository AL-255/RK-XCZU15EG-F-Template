#!/usr/bin/env bash
#
# bit2bin.sh - convert a Vivado .bit into a raw bitstream (.bit.bin) that the
# ZynqMP Linux FPGA manager can load at run time, and (optionally) emit a
# device-tree overlay that references it.
#
#   bit2bin.sh design.bit [out_dir]
#
# Produces:  <out_dir>/design.bit.bin
# Copy that to the board's /lib/firmware and run:  load-bitstream.sh design.bit.bin
#
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/env.sh" --with-xilinx

BIT="${1:?usage: bit2bin.sh design.bit [out_dir]}"
OUT="${2:-$(dirname "$BIT")}"
[ -r "$BIT" ] || die "cannot read $BIT"
command -v bootgen >/dev/null || die "bootgen not found - source Vitis/Vivado settings64.sh"

base="$(basename "${BIT%.bit}")"
bif="$(mktemp)"
printf 'all:\n{\n    [destination_device=pl] %s\n}\n' "$BIT" > "$bif"

mkdir -p "$OUT"
log "bootgen: $BIT -> $OUT/${base}.bit.bin"
bootgen -image "$bif" -arch zynqmp -process_bitstream bin -o /dev/null -w
# bootgen writes <bit>.bin next to the input; normalise the name/location.
src="${BIT%.bit}.bit.bin"; [ -f "$src" ] || src="${BIT}.bin"
mv -f "$src" "$OUT/${base}.bit.bin"
rm -f "$bif"
log "raw bitstream -> $OUT/${base}.bit.bin"
