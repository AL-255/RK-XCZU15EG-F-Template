# RK-XCZU15EG-F Board Overview

Hardware reference for the **RK-XCZU15EG-F** development board.

- **Vendor:** RIGUKE (日固刻)
- **Family:** Clone-family of the ALINX / 正点原子 (ALIENTEK) MPSoC-P5
- **SoC:** Xilinx Zynq UltraScale+ **XCZU15EG-FFVB1156-2-I** (package FFVB1156, speed grade −2, industrial temperature)
- **Form factor:** Core board (核心板) + base board (底板)

---

## Overview

The RK-XCZU15EG-F is a two-board Zynq UltraScale+ MPSoC platform. A core board carries the
XCZU15EG SoC, PS DDR4, eMMC, and QSPI boot flash; a base board (底板) carries the I/O,
connectors, Ethernet PHYs, USB, DisplayPort, PCIe, and user peripherals.

The XCZU15EG combines a quad-core Arm Cortex-A53 application processor (APU), a dual-core
Cortex-R5F real-time unit (RPU), a Mali-400 MP2 GPU, and a large UltraScale+ programmable
logic (PL) fabric with GTH/GTY transceivers in a single device. This document describes the
board-level wiring as enabled by the base BSP/device-tree preset.

This board boots Linux from the micro-SD card by default and provides an SSH-capable
Gigabit Ethernet link out of the box, without any PL bitstream loaded.

---

## Block summary

| Block | Implementation | Interface / location | Notes |
|-------|----------------|----------------------|-------|
| SoC | XCZU15EG-FFVB1156-2-I | FFVB1156 BGA | Quad A53 + dual R5F + PL |
| PS DDR4 | 4 GB, DDR4-2400 | 64-bit, PS DDR controller | ECC disabled |
| PL DDR4 | Separate bank | DDR4/MIG IP, fabric side | 200 MHz ref on AL8 |
| eMMC | Samsung KLM8G1GETF-B041, 8 GB | PS SD0, bank 500, 8-bit | `mmcblk0`, non-removable |
| micro-SD | SD 2.0, 4-bit | PS SD1 | `mmcblk1`, boot + rootfs |
| QSPI flash | 2 × Macronix MX25U51245GZ4I00 | MIO0–12, Dual-Parallel x4 | 128 MB total boot flash |
| Console UART | PS UART0 | MIO42–43, USB-UART | `ttyPS0`, 115200 8N1 |
| Ethernet 0 | PS GEM3 (ENET3) | MIO64–77 RGMII | RTL8211F, primary/SSH NIC |
| Ethernet 1 | PS GEM0 via EMIO | PL gmii_to_rgmii core | RTL8211F, needs bitstream |
| I2C1 | PS I2C1 | MIO24–25 | AT24C256 EEPROM @ 0x50 |
| CAN | CAN0 / CAN1 | MIO38–39 / MIO32–33 | |
| USB 3.0 | DWC3 | MIO52–63 ULPI + GT lane | Host mode |
| DisplayPort | DP | GT lanes (Dual Higher) | DPAUX MIO27–30 |
| PCIe | Root port | GT Lane0, x1 | 5.0 Gb/s |
| Clock gen | AD9523-1 PLL | Transceiver/MIPI refs | Optional for PS boot |

---

## Memory map

### PS DDR4

- **Capacity:** 4 GB total
- **Speed:** DDR4-2400 (1200 MHz clock)
- **Bus width:** 64-bit
- **ECC:** disabled

| Region | Start | End | Size |
|--------|-------|-----|------|
| DDR_LOW | `0x0000_0000` | `0x7FFF_FFFF` | 2 GB |
| DDR_HIGH | `0x8_0000_0000` | `0x8_7FFF_FFFF` | 2 GB |

### PL DDR4

A **separate** fabric-side DDR4 bank, driven by a DDR4/MIG IP in the PL. It is distinct from
the PS DDR4 above and is only available when a PL design instantiating the controller is
loaded. Its 200 MHz reference clock is a differential SSTL12 pair on pin **AL8**
(`DIFF_SSTL12`).

---

## Storage

| Device | Part | Size | Controller | Linux node | Removable |
|--------|------|------|------------|------------|-----------|
| eMMC | Samsung KLM8G1GETF-B041 | 8 GB | PS SD0 (sdhci0) | `mmcblk0` | No |
| micro-SD | — | — | PS SD1 (sdhci1) | `mmcblk1` | Yes |
| QSPI flash | 2 × Macronix MX25U51245GZ4I00 | 128 MB | QSPI | — | No |

**eMMC:** wired to PS bank 500 with an 8-bit data width on the PS SD0 controller. Non-removable.

**micro-SD:** SD 2.0, 4-bit, on the PS SD1 controller. Card-detect is on **MIO45**. This is the
default **boot + rootfs** medium.

**QSPI boot flash:** two Macronix MX25U51245GZ4I00 devices, each 512 Mbit (64 MB), for a total
of 1 Gbit (128 MB). Configured as **Dual-Parallel x4** on MIO0–12, with the feedback clock on
**MIO6**.

---

## Networking

### Primary Ethernet (SSH NIC)

- **MAC:** PS GEM3 (ENET3)
- **Pins:** MIO64–75 RGMII, MDIO on MIO76–77
- **PHY:** Realtek **RTL8211F** (RGMII, `rgmii-id`)

This is the default network interface and the one used for SSH. It is fully functional from
PS Linux with no PL bitstream required.

### Secondary Ethernet

- **MAC:** PS GEM0, routed through **EMIO** to a PL **`gmii_to_rgmii`** core
- **Pins:** PL-side RGMII pins (LVCMOS18) out to a second RTL8211F
- **Requirement:** only works when a PL bitstream containing the `gmii_to_rgmii` core is loaded.

### Other serial buses

| Bus | Pins | Devices |
|-----|------|---------|
| I2C1 | MIO24–25 | AT24C256 EEPROM @ 0x50 |
| I2C0 | — | Disabled in base preset |
| CAN0 | MIO38–39 | |
| CAN1 | MIO32–33 | |

---

## Serial console

- **Controller:** PS UART0
- **Pins:** MIO42–43
- **Settings:** 115200 8N1
- **Physical:** exposed through an on-board USB-UART bridge
- **Linux console:** `ttyPS0`, stdout `serial0`

---

## USB / DisplayPort / PCIe

### USB 3.0

- **Controller:** DWC3
- **Pins:** MIO52–63 (ULPI) plus a GT lane for the SuperSpeed link
- **Reset:** MIO44 (active low)
- **Mode:** Host

### DisplayPort

- **Lanes:** GT lanes (Dual Higher)
- **AUX:** DPAUX on MIO27–30
- **Reference clock:** 27 MHz

### PCIe

- **Mode:** Root port
- **Lanes:** x1 on GT Lane0
- **Rate:** 5.0 Gb/s
- **Reset:** MIO37

---

## GPIO / LED / Key map

ZynqMP GPIO numbering: **MIO = gpio 0–77**, **EMIO = gpio 78 and up**.

### LEDs

| Name | Source | gpio # | Polarity / notes |
|------|--------|--------|------------------|
| core_y | EMIO | 78 | Active low |
| core_g | EMIO | 79 | Active low |
| core_r | EMIO | 80 | Active low |
| ps_led1 | MIO35 | 35 | |
| ps_led2 | MIO26 | 26 | |
| ps_led3 | MIO31 | 31 | |
| ps_led4 | MIO41 | 41 | |
| pl_led1 | EMIO | 81 | |
| pl_led2 | EMIO | 82 | |

Direct-fabric PL LED pins also exist at **AP12 / AN14 / AP14 / C16** (LVCMOS33), driven
directly from the PL.

### Keys / buttons

| Name | Source | gpio # | Notes |
|------|--------|--------|-------|
| ps_key1 | MIO40 | 40 | |
| ps_key2 | MIO34 | 34 | |
| pl_key1 | EMIO | 83 | |
| pl_key2 | EMIO | 84 | |

A PL reset/key button is also available at pin **F16** (LVCMOS33).

---

## Clocking

| Clock | Frequency | Location | Purpose |
|-------|-----------|----------|---------|
| PL DDR4 ref | 200 MHz | AL8 (DIFF_SSTL12) | MIG/DDR4 IP reference |
| DisplayPort ref | 27 MHz | — | DP link |
| AD9523-1 outputs | programmable | PLL chip | GTH/GTY transceiver + MIPI refs |

The board carries an on-board **AD9523-1** programmable PLL clock generator that produces the
transceiver (GTH/GTY) and MIPI reference clocks. It is **not** required for a basic PS Linux
boot or for Ethernet/SSH; it is only needed for transceiver and MIPI features.

---

## Boot modes

Two identical boot-mode DIP switches exist — one on the core board, one on the base board —
with the same function. The **ON side selects 0**, and the switch order is **4 3 2 1**.

| Boot source | SW 4 3 2 1 |
|-------------|------------|
| SD card (SD1) | 0 1 0 1 |
| QSPI32 | 0 0 1 0 |
| eMMC (SD0) | 0 1 1 0 |
| JTAG | 0 0 0 0 |

The default configuration boots from the **SD card (SD1)**.

---

## Connectors / JTAG

| Header | Location | Type |
|--------|----------|------|
| JTAG | Base board | 2×5P standard |
| JTAG | Core board | 1×6P, 3.3 V |

---

## Power

- **Input:** 12 V DC (operating range 10–14 V)
- **Power button:** SW1

---

## BSP scope: enabled vs. needs extra work

**Enabled by the base BSP / device tree (PS-only, no bitstream required):**

- Boot from micro-SD (SD1) → `mmcblk1`, with rootfs on the same medium
- eMMC (`mmcblk0`) and QSPI boot flash
- Serial console on `ttyPS0` (115200 8N1) via the USB-UART bridge
- Primary Gigabit Ethernet (GEM3 → RTL8211F) — the SSH NIC
- I2C1 + AT24C256 EEPROM, CAN0/CAN1
- USB 3.0 host (DWC3), DisplayPort, PCIe root port
- PS LEDs and keys, plus the EMIO-mapped core/PL LED and key GPIOs

**Requires additional work (PL bitstream and/or clock configuration):**

- **Secondary Ethernet** (GEM0 via EMIO `gmii_to_rgmii`): needs a PL bitstream containing the
  `gmii_to_rgmii` core before the second RTL8211F is usable.
- **PL DDR4 bank**: requires a DDR4/MIG IP instantiated in the PL design.
- **Transceiver / MIPI features** (GTH/GTY links beyond the fixed DP/PCIe/USB assignments):
  require the on-board **AD9523-1** PLL to be programmed for the appropriate reference clocks.
- **Direct-fabric PL LEDs/keys** (AP12/AN14/AP14/C16, F16): only driven when a PL design maps them.

---

### Toolchain / software baseline

- **Tools:** Vivado / Vitis / XSCT **2025.2**
- **U-Boot / ATF / Linux:** upstream Xilinx tag **xilinx-v2025.2**
- **Device tree:** `device-tree-xlnx` branch **xlnx_rel_v2025.2**
- **Kernel:** Linux **6.12**
