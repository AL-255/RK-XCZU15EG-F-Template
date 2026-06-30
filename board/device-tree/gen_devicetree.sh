#!/usr/bin/env bash
#
# gen_devicetree.sh - generate the RK-XCZU15EG-F device tree from the hardware
#                     hand-off (XSA) using the Xilinx device-tree generator,
#                     then layer board/device-tree/system-user.dtsi on top and
#                     compile a flattened system.dtb.
#
# Requires: Vitis/XSCT 2025.2 (xsct), device-tree-xlnx, dtc, gcc (cpp).
#
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/scripts/env.sh" --with-xilinx

XSA="${XSA:-$ROOT/board/hw-handoff/IMAGE_15EG.xsa}"
DTX="${DEVICE_TREE_XLNX:-$SRC_DIR/device-tree-xlnx}"
OUT="${1:-$BUILD_DIR/device-tree}"
PROC="${PROC:-psu_cortexa53_0}"

[ -r "$XSA" ]      || { echo "ERROR: XSA not found: $XSA"; exit 1; }
[ -d "$DTX" ]      || { echo "ERROR: device-tree-xlnx not found at $DTX (set DEVICE_TREE_XLNX or run scripts/fetch_sources.sh)"; exit 1; }
command -v xsct >/dev/null || { echo "ERROR: xsct not on PATH - source Vitis settings64.sh"; exit 1; }

mkdir -p "$OUT"
echo ">> Generating base device tree from $XSA"

cat > "$BUILD_DIR/_gen_dts.tcl" <<TCL
hsi::open_hw_design $XSA
hsi::set_repo_path $DTX
hsi::create_sw_design device-tree -os device_tree -proc $PROC
hsi::generate_target -dir $OUT
hsi::close_hw_design [hsi::current_hw_design]
TCL
xsct "$BUILD_DIR/_gen_dts.tcl"

# Overlay our board customisation on top of the generated tree.  The raw
# device-tree-xlnx generator (unlike PetaLinux) does not pull in a user dtsi,
# so we install ours and append an #include to system-top.dts.
echo ">> Installing board system-user.dtsi"
cp "$HERE/system-user.dtsi" "$OUT/system-user.dtsi"
if ! grep -q 'system-user.dtsi' "$OUT/system-top.dts"; then
    printf '\n#include "system-user.dtsi"\n' >> "$OUT/system-top.dts"
fi

# Flatten + compile.  system-top.dts pulls in pcw/pl/zynqmp + system-user.
echo ">> Compiling system.dtb"
gcc -I "$OUT" -I "$OUT/include" -E -nostdinc -undef -D__DTS__ \
    -x assembler-with-cpp "$OUT/system-top.dts" -o "$BUILD_DIR/system-top.dts.pp"
# -@ keeps __symbols__ so runtime device-tree overlays (e.g. PL bitstream
# loading via &fpga_full) can resolve labels against the live tree.
dtc -@ -q -I dts -O dtb -o "$BUILD_DIR/system.dtb" "$BUILD_DIR/system-top.dts.pp"
cp "$BUILD_DIR/system.dtb" "$OUT_DIR/system.dtb" 2>/dev/null || true

echo ">> Device tree ready:"
echo "   sources : $OUT/"
echo "   blob    : $BUILD_DIR/system.dtb"
