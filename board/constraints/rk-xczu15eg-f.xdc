## =============================================================================
##  RK-XCZU15EG-F  -  master physical constraints (PL I/O)
##  Device: xczu15eg-ffvb1156-2-i
## -----------------------------------------------------------------------------
##  Pin assignments are taken verbatim from the vendor's own working demo
##  projects (RIGUKE-ZU15EG-FPGA-DEMO) and cross-checked against the base-board
##  schematic.  Each block is self-contained: copy the blocks whose ports your
##  top-level actually drives.  PS peripherals (UART0 console, GEM3, SD, eMMC,
##  QSPI, USB, CAN, I2C ...) are NOT here - they are fixed MIO and live in the
##  PS preset (board/XCZU15EG_Base_Config.tcl).
##
##  Only the positive/true pin of each differential pair is constrained; Vivado
##  derives the complementary pin from the package (vendor convention).
## =============================================================================

## -----------------------------------------------------------------------------
## 200 MHz system / PL-DDR4 reference clock  (bank 65/66, SSTL12 diff)
## -----------------------------------------------------------------------------
set_property PACKAGE_PIN AL8        [get_ports sys_clk_200m_p]
set_property IOSTANDARD  DIFF_SSTL12 [get_ports sys_clk_200m_p]
create_clock -name sys_clk_200m -period 5.000 [get_ports sys_clk_200m_p]

## -----------------------------------------------------------------------------
## User LEDs  (LVCMOS33, active high)   -- PL fabric LEDs on the base board
## -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN AP12 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN AN14 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN AP14 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN C16  IOSTANDARD LVCMOS33} [get_ports {led[3]}]

## -----------------------------------------------------------------------------
## Push buttons / reset  (LVCMOS33, active low)
## -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN F16  IOSTANDARD LVCMOS33} [get_ports rst_n]

## -----------------------------------------------------------------------------
## PL UART  (LVCMOS33)  -- the FPGA-side TTL UART (separate from PS UART0 console)
## -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN E15  IOSTANDARD LVCMOS33} [get_ports uart_rx]
set_property -dict {PACKAGE_PIN D15  IOSTANDARD LVCMOS33} [get_ports uart_tx]

## -----------------------------------------------------------------------------
## RS-485  (LVCMOS33)
## -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN E14  IOSTANDARD LVCMOS33} [get_ports rs485_rx]
set_property -dict {PACKAGE_PIN C13  IOSTANDARD LVCMOS33} [get_ports rs485_tx]
set_property -dict {PACKAGE_PIN D14  IOSTANDARD LVCMOS33} [get_ports rs485_de]

## -----------------------------------------------------------------------------
## PL Gigabit Ethernet - RGMII to a second on-board RTL8211F PHY (LVCMOS18)
## (The PRIMARY Ethernet used for SSH is PS GEM3 via MIO - see the PS preset.)
## -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN AC8  IOSTANDARD LVCMOS18} [get_ports eth_txc]
set_property -dict {PACKAGE_PIN AB8  IOSTANDARD LVCMOS18} [get_ports eth_tx_ctl]
set_property -dict {PACKAGE_PIN AA12 IOSTANDARD LVCMOS18} [get_ports {eth_txd[3]}]
set_property -dict {PACKAGE_PIN AA6  IOSTANDARD LVCMOS18} [get_ports {eth_txd[2]}]
set_property -dict {PACKAGE_PIN AC12 IOSTANDARD LVCMOS18} [get_ports {eth_txd[1]}]
set_property -dict {PACKAGE_PIN AC11 IOSTANDARD LVCMOS18} [get_ports {eth_txd[0]}]
set_property -dict {PACKAGE_PIN AA7  IOSTANDARD LVCMOS18} [get_ports eth_rxc]
set_property -dict {PACKAGE_PIN AB9  IOSTANDARD LVCMOS18} [get_ports eth_rx_ctl]
set_property -dict {PACKAGE_PIN AB11 IOSTANDARD LVCMOS18} [get_ports {eth_rxd[3]}]
set_property -dict {PACKAGE_PIN AB10 IOSTANDARD LVCMOS18} [get_ports {eth_rxd[2]}]
set_property -dict {PACKAGE_PIN AB4  IOSTANDARD LVCMOS18} [get_ports {eth_rxd[1]}]
set_property -dict {PACKAGE_PIN AC4  IOSTANDARD LVCMOS18} [get_ports {eth_rxd[0]}]

## -----------------------------------------------------------------------------
## General bitstream / configuration settings (recommended for ZynqMP PL)
## -----------------------------------------------------------------------------
set_property BITSTREAM.GENERAL.COMPRESS        TRUE  [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN        Pullnone [current_design]
## Required so a .bit can be loaded from Linux via the PCAP/FPGA-manager.
## (PetaLinux/Vitis set this automatically; kept here for the manual flow.)
