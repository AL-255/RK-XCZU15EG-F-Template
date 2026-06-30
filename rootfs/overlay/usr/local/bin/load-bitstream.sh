#!/bin/sh
# =============================================================================
#  load-bitstream.sh  -  program the PL from the running PS (Linux) on ZynqMP
# -----------------------------------------------------------------------------
#  RK-XCZU15EG-F.  Uses the kernel FPGA manager (PCAP) to configure the FPGA
#  fabric at run time - no reboot, no JTAG, no rebuilt BOOT.BIN.
#
#  Usage:
#     load-bitstream.sh <design.bit.bin> [--partial]
#     load-bitstream.sh --status
#
#  <design.bit.bin> is a RAW bitstream (Vivado .bit run through bootgen):
#     bootgen -image x.bif -arch zynqmp -o /dev/null -process_bitstream bin
#  (a .bif containing just "[destination_device=pl] x.bit").  See
#  scripts/bit2bin.sh in the template.  A normal .bit usually also works -
#  the zynqmp-fpga driver strips the header - but raw .bin is canonical.
#
#  Two mechanisms are attempted, most-portable first:
#    1. device-tree overlay via configfs + &fpga_full   (mainline standard)
#    2. legacy Xilinx sysfs  flags/firmware              (older Xilinx kernels)
# =============================================================================
set -e

FW_DIR=/lib/firmware
FPGA=/sys/class/fpga_manager/fpga0
OVL_ROOT=/sys/kernel/config/device-tree/overlays
OVL_NAME=rk-fpga-full

die()  { echo "load-bitstream: $*" >&2; exit 1; }
info() { echo "load-bitstream: $*"; }

if [ "${1:-}" = "--status" ]; then
    [ -d "$FPGA" ] || die "no fpga_manager - is CONFIG_FPGA_MGR_ZYNQMP_FPGA enabled?"
    echo "fpga manager : $(cat "$FPGA/name" 2>/dev/null)"
    echo "state        : $(cat "$FPGA/state" 2>/dev/null)"
    echo "overlays     : $(ls "$OVL_ROOT" 2>/dev/null || echo none)"
    exit 0
fi

BIT="${1:-}"
[ -n "$BIT" ] || die "usage: load-bitstream.sh <design.bit.bin> [--partial]"
[ -r "$BIT" ] || die "cannot read bitstream: $BIT"
[ -d "$FPGA" ] || die "no /sys/class/fpga_manager/fpga0 (FPGA manager driver missing)"

PARTIAL=0
[ "${2:-}" = "--partial" ] && PARTIAL=1

BASENAME=$(basename "$BIT")
install -D -m 0644 "$BIT" "$FW_DIR/$BASENAME"
info "installed firmware $FW_DIR/$BASENAME"

# ---- method 1: device-tree overlay (configfs) -------------------------------
try_overlay() {
    [ -d /sys/kernel/config ] || mount -t configfs none /sys/kernel/config 2>/dev/null || return 1
    command -v dtc >/dev/null 2>&1 || return 1
    [ -d "$OVL_ROOT/$OVL_NAME" ] && rmdir "$OVL_ROOT/$OVL_NAME" 2>/dev/null || true

    EXT=""; [ "$PARTIAL" = 1 ] && EXT="external-fpga-config; partial-fpga-config;"
    TMP=$(mktemp -d)
    cat > "$TMP/ovl.dts" <<DTS
/dts-v1/;
/plugin/;
&fpga_full {
    #address-cells = <2>;
    #size-cells = <2>;
    firmware-name = "$BASENAME";
    $EXT
};
DTS
    dtc -@ -I dts -O dtb -o "$TMP/ovl.dtbo" "$TMP/ovl.dts" 2>/dev/null || { rm -rf "$TMP"; return 1; }
    mkdir -p "$OVL_ROOT/$OVL_NAME"
    cat "$TMP/ovl.dtbo" > "$OVL_ROOT/$OVL_NAME/dtbo" || { rmdir "$OVL_ROOT/$OVL_NAME" 2>/dev/null; rm -rf "$TMP"; return 1; }
    rm -rf "$TMP"
    return 0
}

# ---- method 2: legacy Xilinx sysfs ------------------------------------------
try_sysfs() {
    [ -w "$FPGA/firmware" ] || return 1
    if [ -w "$FPGA/flags" ]; then
        # 0 = full bitstream, 1 = partial
        echo "$PARTIAL" > "$FPGA/flags" 2>/dev/null || true
    fi
    echo "$BASENAME" > "$FPGA/firmware"
    return 0
}

if try_overlay; then
    info "programmed via device-tree overlay (&fpga_full)"
elif try_sysfs; then
    info "programmed via legacy fpga_manager sysfs"
else
    die "no working FPGA-manager mechanism (need OF_OVERLAY+configfs+dtc, or the Xilinx firmware sysfs)"
fi

sleep 1
STATE=$(cat "$FPGA/state" 2>/dev/null || echo unknown)
info "fpga state: $STATE"
[ "$STATE" = "operating" ] || info "WARNING: expected state 'operating'"
