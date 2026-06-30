# `board/` — the RK-XCZU15EG-F board definition (BSP core)

Everything that makes this *this board* lives here. It is toolchain-version
agnostic and is the part you keep when starting a new project.

| path | what it is | when you touch it |
|------|------------|-------------------|
| `XCZU15EG_Base_Config.tcl` | PS preset: MIO pin-mux, 4 GB DDR4-2400, clocks, and which PS peripherals are on (QSPI, eMMC/SD0, SD1, UART0, GEM3, I2C1, CAN0/1, USB3, DP, PCIe). | only if you change PS peripheral usage (re-export from Vivado). |
| `constraints/rk-xczu15eg-f.xdc` | PL pin constraints: 200 MHz clock, LEDs, keys, PL UART, RS-485, PL RGMII Ethernet. | add your top-level's ports. |
| `constraints/rk-xczu15eg-f-pl-ddr4.xdc` | PL-side DDR4 bank ball assignment (for a DDR4/MIG IP). | only if you use the PL DDR4. |
| `device-tree/system-user.dtsi` | board device-tree overrides: LEDs/keys, GEM3 MAC, secondary `phy1`, eMMC/SD, QSPI flash map, I2C EEPROM, USB3, CAN, kernel cmdline. | when your PL/peripheral usage changes. |
| `device-tree/gen_devicetree.sh` | regenerates the base device tree from an XSA (XSCT + device-tree-xlnx) and layers `system-user.dtsi`, compiling `system.dtb` with `dtc -@`. | run it, don't edit it. |
| `hw-handoff/` | golden factory XSA + bitstream + `psu_init` (see its README). | reference / fallback. |

The PS pin-mux (MIO) is fixed by the preset and is **not** in the XDC — only the
PL fabric I/O is. See `../docs/05-pinout-reference.md` for the full map and
`../docs/02-architecture.md` for how these pieces combine at boot.
