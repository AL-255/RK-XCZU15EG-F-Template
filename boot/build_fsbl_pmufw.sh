#!/usr/bin/env bash
#
# build_fsbl_pmufw.sh - build the Zynq UltraScale+ FSBL and PMU firmware from
# the hardware hand-off (XSA) using XSCT.  These are the first two stages of
# BOOT.BIN: the FSBL configures the PS (DDR, MIO, clocks via psu_init) and the
# PMUFW runs on the platform-management unit.
#
# Output: $OUT_DIR/fsbl.elf  $OUT_DIR/pmufw.elf
#
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../scripts/env.sh" --with-xilinx

XSA="${XSA:-$ROOT/board/hw-handoff/IMAGE_15EG.xsa}"
WS="$BUILD_DIR/fsbl_ws"
command -v xsct >/dev/null || die "xsct not found - install/locate Vitis $XILINX_VERSION"
[ -r "$XSA" ] || die "XSA not found: $XSA"

rm -rf "$WS"; mkdir -p "$WS"
log "Building FSBL + PMUFW from $XSA"

cat > "$WS/build.tcl" <<TCL
setws $WS
app create -name fsbl  -hw $XSA -proc psu_cortexa53_0 -os standalone -template {Zynq MP FSBL}
app create -name pmufw -hw $XSA -proc psu_pmu_0        -os standalone -template {ZynqMP PMU Firmware}
app build -name fsbl
app build -name pmufw
TCL
xsct "$WS/build.tcl"

# Vitis writes to <app>/Debug (or <app>/build depending on version); locate it.
fsbl=$(find "$WS/fsbl"  -name 'fsbl.elf'  -newer "$WS/build.tcl" 2>/dev/null | head -1)
pmu=$( find "$WS/pmufw" -name 'pmufw.elf' -newer "$WS/build.tcl" 2>/dev/null | head -1)
[ -n "$fsbl" ] || fsbl=$(find "$WS" -name 'fsbl*.elf' | head -1)
[ -n "$pmu"  ] || pmu=$( find "$WS" -name 'pmufw.elf' | head -1)
[ -r "$fsbl" ] || die "fsbl.elf not produced"
[ -r "$pmu"  ] || die "pmufw.elf not produced"
cp "$fsbl" "$OUT_DIR/fsbl.elf"
cp "$pmu"  "$OUT_DIR/pmufw.elf"
log "FSBL  -> $OUT_DIR/fsbl.elf"
log "PMUFW -> $OUT_DIR/pmufw.elf"
