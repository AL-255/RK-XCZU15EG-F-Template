# RK-XCZU15EG-F — Pinout Reference

**Device:** XCZU15EG-FFVB1156-2-I (Zynq UltraScale+ MPSoC)
**Board:** RK-XCZU15EG-F

This board has two distinct classes of I/O, and they are configured in two
completely different places:

- **PL fabric I/O (Part A)** — pins on the FPGA programmable-logic side. These
  are package balls assigned by **constraint files (XDC)** and only take effect
  when the PL bitstream is loaded. You change them by editing the XDC.
- **PS MIO (Part B)** — the Multiplexed I/O of the Processing System. These are
  **fixed by the PS preset** (the `XCZU15EG_Base_Config.tcl` block design
  configuration), *not* by the XDC. The MIO multiplexing is baked into the PS
  configuration; you cannot reassign a peripheral to a different MIO pin from a
  constraints file.

> **Diff-pair convention:** For differential signals, the constraints only
> declare the **positive (`_p` / `_t`) pin**. Vivado automatically infers the
> negative (`_n` / `_c`) pin of the pair from the package, so it is intentionally
> absent from the XDC.

---

## Part A — PL Fabric I/O (package ball assignments)

Source: [`board/constraints/rk-xczu15eg-f.xdc`](../board/constraints/rk-xczu15eg-f.xdc)

### Clock

| Signal            | Ball | IOSTANDARD   | Notes                                                        |
|-------------------|------|--------------|-------------------------------------------------------------|
| `sys_clk_200m_p`  | AL8  | DIFF_SSTL12  | 200 MHz system / PL-DDR4 reference clock. Positive pin only; N pin inferred. |

### User LEDs (LVCMOS33, active-high)

| Signal   | Ball |
|----------|------|
| `led[0]` | AP12 |
| `led[1]` | AN14 |
| `led[2]` | AP14 |
| `led[3]` | C16  |

### Button / Reset (LVCMOS33, active-low)

| Signal  | Ball | Notes              |
|---------|------|--------------------|
| `rst_n` | F16  | Reset / key button |

### PL UART (LVCMOS33)

| Signal    | Ball |
|-----------|------|
| `uart_rx` | E15  |
| `uart_tx` | D15  |

### RS-485 (LVCMOS33)

| Signal      | Ball | Notes              |
|-------------|------|--------------------|
| `rs485_rx`  | E14  | Receive            |
| `rs485_tx`  | C13  | Transmit           |
| `rs485_de`  | D14  | Driver enable      |

### PL RGMII Ethernet (LVCMOS18)

Connects to a second on-board RTL8211F PHY (independent of the PS GEM3 PHY).

| Signal         | Ball | Signal         | Ball |
|----------------|------|----------------|------|
| `eth_txc`      | AC8  | `eth_rxc`      | AA7  |
| `eth_tx_ctl`   | AB8  | `eth_rx_ctl`   | AB9  |
| `eth_txd[0]`   | AA12 | `eth_rxd[0]`   | AB11 |
| `eth_txd[1]`   | AA6  | `eth_rxd[1]`   | AB10 |
| `eth_txd[2]`   | AC12 | `eth_rxd[2]`   | AB4  |
| `eth_txd[3]`   | AC11 | `eth_rxd[3]`   | AC4  |

### PL-side DDR4

A separate, large pinout (~68 pins) for the PL-attached DDR4 is generated and
driven by the **DDR4 MIG IP**. It lives in its own constraint file:

Source: [`board/constraints/rk-xczu15eg-f-pl-ddr4.xdc`](../board/constraints/rk-xczu15eg-f-pl-ddr4.xdc)

This file uses the same `AL8` 200 MHz reference clock. A few representative balls:

| Signal              | Ball |
|---------------------|------|
| `c0_ddr4_act_n`     | AM9  |
| `c0_ddr4_reset_n`   | AM5  |
| `c0_ddr4_ck_t[0]`   | AL6  |
| `c0_ddr4_cs_n[0]`   | AN4  |
| `c0_ddr4_cke[0]`    | AK10 |
| `c0_ddr4_adr[0]`    | AN9  |

> The full data/address/strobe bus is **not** listed here. Refer to the
> `rk-xczu15eg-f-pl-ddr4.xdc` file for the complete set of assignments.

---

## Part B — PS MIO Map (fixed by PS preset)

Source: [`board/XCZU15EG_Base_Config.tcl`](../board/XCZU15EG_Base_Config.tcl)

These assignments are part of the **PS preset / block-design configuration** and
are fixed in hardware-config terms. They are not editable from the XDC.

| MIO     | Function                       | Notes                                  |
|---------|--------------------------------|----------------------------------------|
| 0–12    | QSPI (Dual Parallel x4)         | Feedback clock on MIO6                 |
| 13–22   | SD0 = eMMC (8-bit)              | On-board eMMC                          |
| 23      | eMMC power / reset              |                                        |
| 24–25   | I2C1                            |                                        |
| 26      | GPIO — `ps_led2`                |                                        |
| 27–30   | DPAUX                           | DisplayPort AUX channel                |
| 31      | GPIO — `ps_led3`                |                                        |
| 32–33   | CAN1                            |                                        |
| 34      | GPIO — `ps_key2`                |                                        |
| 35      | GPIO — `ps_led1`                |                                        |
| 37      | PCIe reset                      |                                        |
| 38–39   | CAN0                            |                                        |
| 40      | GPIO — `ps_key1`                |                                        |
| 41      | GPIO — `ps_led4`                |                                        |
| 42–43   | UART0                           | Serial console                         |
| 44      | USB0 reset                      |                                        |
| 45      | SD1 card-detect                 |                                        |
| 46–51   | SD1 (micro-SD, 4-bit)           |                                        |
| 52–63   | USB0 (ULPI)                     |                                        |
| 64–75   | GEM3 (ENET3) RGMII              | PS Ethernet PHY (RTL8211F)             |
| 76–77   | GEM3 MDIO                       | Management interface                   |

> MIO36 is not assigned in this preset.

### EMIO GPIO (require the PL bitstream)

These are extended MIO (EMIO) GPIO routed through the PL. They are only usable
when a PL bitstream that wires them out is loaded.

| EMIO | Function           |
|------|--------------------|
| 78   | `core_y`           |
| 79   | `core_g`           |
| 80   | `core_r`           |
| 81   | `pl_led1`          |
| 82   | `pl_led2`          |
| 83   | `pl_key1`          |
| 84   | `pl_key2`          |
| 93   | `PWRGD` (factory design) |

---

## GPIO Controller Numbering

The ZynqMP GPIO controller numbers its lines as follows:

- **MIO 0–77** map directly to **gpio 0–77**.
- **EMIO starts at gpio 78** (so EMIO line 0 = gpio 78, matching the EMIO table
  above where `core_y` = 78, etc.).

To compute a Linux sysfs GPIO number, add the controller base (per your kernel /
device tree) to these offsets.
