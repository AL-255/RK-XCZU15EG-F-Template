#!/usr/bin/env bash
#
# build_boot.sh - build the whole first-stage boot chain and assemble BOOT.BIN.
#   FSBL + PMUFW (from XSA)  ->  ATF/BL31  ->  U-Boot (+ boot.scr)  ->  BOOT.BIN
#
# Pass a bitstream path to embed the PL in BOOT.BIN (otherwise the PL is left
# for Linux to program from the PS side - the default).
#
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "$HERE/../scripts/env.sh"

log "[1/4] FSBL + PMUFW";          "$HERE/build_fsbl_pmufw.sh"
log "[2/4] ATF (BL31)";            "$HERE/build_atf.sh"
log "[3/4] U-Boot + boot.scr";     "$HERE/build_uboot.sh"
log "[4/4] BOOT.BIN";              "$HERE/make_boot_bin.sh" "${1:-}"

log "Boot artefacts in $OUT_DIR:"
ls -la "$OUT_DIR"/BOOT.BIN "$OUT_DIR"/boot.scr 2>/dev/null || true
