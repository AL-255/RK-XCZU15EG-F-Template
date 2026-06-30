# =============================================================================
#  create_project.tcl  -  RK-XCZU15EG-F base hardware platform
# -----------------------------------------------------------------------------
#  Builds a Zynq UltraScale+ block design from the board PS preset
#  (XCZU15EG_Base_Config), exposes EMIO GPIO for the on-board PL LEDs/keys,
#  adds one example AXI-GPIO in the PL, then (optionally) runs implementation
#  and exports an XSA + bitstream.
#
#  The PL is intentionally minimal: this is the *base* platform that boots
#  Linux and lets you load richer bitstreams from the PS at run time.  Drop
#  your own IP into the "USER PL LOGIC" section and rebuild.
#
#  Usage:
#     vivado -mode batch -source hw/create_project.tcl -tclargs <mode> <outdir>
#        mode   = xsa  -> synth + export hardware (fast, for FSBL/device-tree)
#               = all  -> full implementation + bitstream + fixed XSA  (default)
#        outdir = output directory (default: ./build/hw)
# =============================================================================

set THIS   [file normalize [info script]]
set HW_DIR [file dirname $THIS]
set ROOT   [file dirname $HW_DIR]

set MODE   [expr {$argc >= 1 ? [lindex $argv 0] : "all"}]
set OUTDIR [expr {$argc >= 2 ? [lindex $argv 1] : "$ROOT/build/hw"}]

set PART    "xczu15eg-ffvb1156-2-i"
set PRJ      "rk_xczu15eg_f"
set BD       "system"
set PRESET   "$ROOT/board/XCZU15EG_Base_Config.tcl"
set XDC      "$ROOT/board/constraints/rk-xczu15eg-f.xdc"

file mkdir $OUTDIR
puts "## RK-XCZU15EG-F  part=$PART  mode=$MODE  out=$OUTDIR"

create_project $PRJ "$OUTDIR/$PRJ" -part $PART -force
set_property target_language Verilog [current_project]

# -----------------------------------------------------------------------------
# Block design : PS + preset
# -----------------------------------------------------------------------------
create_bd_design $BD
set ps [create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == zynq_ultra_ps_e}] zynq_ultra_ps_e_0]

# Apply the board PS preset.  The file defines apply_preset returning a CONFIG dict.
source $PRESET
set cfg [apply_preset $ps]
# Apply property-by-property so a single unknown key (tool-version drift) cannot
# abort the whole preset.
dict for {k v} $cfg {
    if {[catch {set_property $k $v $ps} em]} { puts "  (skip $k : $em)" }
}

# Expose 16 EMIO GPIO so the device-tree PL LEDs/keys (gpio 78..93) work, and
# make sure the general-purpose AXI master + 100 MHz fabric clock are enabled.
set_property -dict [list \
    CONFIG.PSU__GPIO_EMIO__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__GPIO_EMIO__PERIPHERAL__IO {16} \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
    CONFIG.PSU__MAXIGP0__DATA_WIDTH {32} \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
] $ps

# =====================  USER PL LOGIC  =======================================
# Example: one AXI-GPIO (4 LEDs out / 1 button in) on the GP0 master.
set axi_gpio [create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME==axi_gpio}] axi_gpio_led]
set_property -dict [list CONFIG.C_GPIO_WIDTH {4} CONFIG.C_IS_DUAL {0} CONFIG.C_ALL_OUTPUTS {1}] $axi_gpio

# Smart-connect the PS GP0 master to the AXI-GPIO, auto-wiring clocks/resets.
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config \
    [list Master "/zynq_ultra_ps_e_0/M_AXI_HPM0_FPD" Clk "Auto"] [get_bd_intf_pins $axi_gpio/S_AXI]

# Surface the EMIO GPIO and the AXI-GPIO LEDs as external ports.
make_bd_intf_pins_external  [get_bd_intf_pins $ps/GPIO_0]
make_bd_pins_external       [get_bd_pins $axi_gpio/gpio_io_o]
# =============================================================================

regenerate_bd_layout
validate_bd_design
save_bd_design

# HDL wrapper
make_wrapper -files [get_files [current_bd_design].bd] -top -import
set_property top ${BD}_wrapper [current_fileset]

# Constraints
add_files -fileset constrs_1 -norecurse $XDC

update_compile_order -fileset sources_1

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------
launch_runs synth_1 -jobs [expr {[exec nproc] > 8 ? 8 : [exec nproc]}]
wait_on_run synth_1

if {$MODE eq "all"} {
    launch_runs impl_1 -to_step write_bitstream -jobs [expr {[exec nproc] > 8 ? 8 : [exec nproc]}]
    wait_on_run impl_1
    open_run impl_1
    set BIT "$OUTDIR/${PRJ}.bit"
    write_bitstream -force $BIT
    write_hw_platform -fixed -include_bit -force "$OUTDIR/${PRJ}.xsa"
    puts "## bitstream -> $BIT"
} else {
    write_hw_platform -fixed -force "$OUTDIR/${PRJ}.xsa"
}
puts "## XSA -> $OUTDIR/${PRJ}.xsa"
puts "## DONE"
