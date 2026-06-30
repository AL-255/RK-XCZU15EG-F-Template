#!/usr/bin/env bash
#
# build_hw.sh - run Vivado in batch to generate the base hardware platform
#               (XSA [+ bitstream]) for RK-XCZU15EG-F.
#
#   ./build_hw.sh xsa    # synth only -> XSA (fast; for FSBL / device tree)
#   ./build_hw.sh all    # full implementation -> XSA + bitstream (default)
#
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "$HERE/../scripts/env.sh" --with-xilinx

MODE="${1:-all}"
OUT="$BUILD_DIR/hw"
command -v vivado >/dev/null || die "vivado not found - source Vivado settings64.sh ($XILINX_VERSION)"

mkdir -p "$OUT"
log "Vivado batch: mode=$MODE  out=$OUT"
( cd "$OUT" && vivado -mode batch -notrace -source "$HERE/create_project.tcl" -tclargs "$MODE" "$OUT" )

XSA=$(ls -t "$OUT"/*.xsa 2>/dev/null | head -1) || true
[ -n "${XSA:-}" ] && { cp "$XSA" "$OUT_DIR/system.xsa"; log "XSA -> $OUT_DIR/system.xsa"; }
BIT=$(ls -t "$OUT"/*.bit 2>/dev/null | head -1) || true
[ -n "${BIT:-}" ] && { cp "$BIT" "$OUT_DIR/system.bit"; log "bitstream -> $OUT_DIR/system.bit"; }
