# Architecture — boot flow and who configures what

This board is a Zynq UltraScale+ MPSoC: a hard **Processing System (PS)** —
quad-core Cortex-A53 + dual Cortex-R5 + PMU + DDR4 controller + hardened
peripherals — tightly coupled to the **Programmable Logic (PL)** FPGA fabric.
Understanding the boot flow makes the rest of this template obvious.

## 1. The ZynqMP boot chain

```
   Power on
      │  (BootROM reads the boot-mode pins / DIP switch)
      ▼
 ┌──────────┐   BootROM loads stage 1 from the selected medium (SD/QSPI/eMMC)
 │ BootROM  │   = the first partition of BOOT.BIN
 └────┬─────┘
      ▼
 ┌──────────┐   FSBL (runs on Cortex-A53 #0)
 │  FSBL    │   • applies psu_init: DDR4, MIO mux, clocks, PLLs, SerDes
 │          │   • loads the remaining BOOT.BIN partitions:
 └────┬─────┘       PMUFW → PMU, BL31 → OCM, U-Boot → DDR, (optional .bit → PL)
      ▼
 ┌──────────┐   PMU firmware (runs on the PMU MicroBlaze) — power/clock/reset,
 │  PMUFW   │   error management; stays resident.
 └────┬─────┘
      ▼
 ┌──────────┐   ARM Trusted Firmware BL31 (EL3 secure monitor) — PSCI, SMC.
 │  BL31    │   Hands off to U-Boot at EL2.
 └────┬─────┘
      ▼
 ┌──────────┐   U-Boot (EL2) — brings up the SD controller, runs the distro
 │  U-Boot  │   boot flow, sources boot.scr, loads Image + system.dtb, booti.
 └────┬─────┘
      ▼
 ┌──────────┐   Linux (EL1) — your Debian/Ubuntu userspace, SSH, FPGA manager.
 │  Linux   │
 └──────────┘
```

`BOOT.BIN` (built by `bootgen` from `boot/make_boot_bin.sh`) therefore contains,
in order:

| partition | file | runs on / where |
|-----------|------|-----------------|
| bootloader | `fsbl.elf` | A53 #0 |
| pmufw_image | `pmufw.elf` | PMU |
| *(optional)* | `*.bit` | PL fabric |
| trustzone EL3 | `bl31.elf` | A53, OCM |
| EL2 | `u-boot.elf` | A53, DDR |

> **This template deliberately leaves the bitstream OUT of `BOOT.BIN`.** The PL
> powers up unconfigured and Linux programs it later from the PS side (see
> `docs/04-bitstream-from-ps.md`). That is the whole point — your FPGA design is
> decoupled from the boot image and reloadable at run time. Pass a `.bit` to
> `make boot BITSTREAM=…` only if you want the PL live before Linux starts.

## 2. Who configures the hardware

| concern | configured by | source in this repo |
|---------|---------------|---------------------|
| DDR4, MIO pin-mux, PLLs, clocks, SerDes | **FSBL** via `psu_init` | `board/XCZU15EG_Base_Config.tcl` → XSA → FSBL |
| PS peripheral enable (UART, GEM3, SD, QSPI, USB, CAN, I2C…) | PS preset → device tree | `board/XCZU15EG_Base_Config.tcl`, generated `pcw.dtsi` |
| PL pin placement / I/O standards | Vivado XDC | `board/constraints/*.xdc` |
| Which drivers Linux binds, board specifics | **device tree** | `board/device-tree/system-user.dtsi` (+ generated base) |
| Kernel drivers available | kernel config | `linux/config/rk-xczu15eg-f.cfg` |
| Userspace, services, network, SSH | rootfs | `rootfs/` |

The **PS MIO assignments are fixed** by the preset (they are not in the XDC):
QSPI 0–12, eMMC(SD0) 13–23, I2C1 24–25, DPAUX/CAN/GPIO 26–41, UART0 42–43,
USB-reset 44, SD1 45–51, USB0 52–63, GEM3 64–77. The **PL I/O is in the XDC**.

## 3. The device tree

There are three layers, combined by `board/device-tree/gen_devicetree.sh`:

1. **`zynqmp.dtsi` / `zynqmp-clk-ccf.dtsi`** — the SoC, shipped by Xilinx.
2. **`pcw.dtsi` / `pl.dtsi`** — *generated from the XSA* by the Xilinx device-tree
   generator (XSCT + `device-tree-xlnx`). This reflects exactly which PS
   peripherals the preset enabled and what PL IP exists.
3. **`system-user.dtsi`** — *our* board layer: LEDs/keys, the GEM3 MAC, the
   secondary `phy1`, eMMC/SD tuning, the QSPI flash layout, the I2C EEPROM,
   USB3 host mode, and the kernel command line
   (`root=/dev/mmcblk1p2 … console=ttyPS0,115200`).

The blob is compiled with `dtc -@` so `__symbols__` are retained — this is what
lets you apply **run-time device-tree overlays**, including the FPGA-manager
overlay that programs the PL (`&fpga_full`).

## 4. The SD card

`image/make_sdcard.sh` produces an MBR image with two partitions:

```
 ┌───────────────── sdcard.img ─────────────────┐
 │ p1  FAT32  "BOOT"   (512 MB)                  │
 │     BOOT.BIN  Image  system.dtb  boot.scr     │  <- BootROM + U-Boot read this
 ├───────────────────────────────────────────────┤
 │ p2  ext4   "rootfs" (rest of the card)        │  <- mounted as / (mmcblk1p2)
 │     Debian / Ubuntu userspace + kernel modules│
 └───────────────────────────────────────────────┘
```

`mmcblk1` is the micro-SD (PS SD1); `mmcblk0` is the on-board eMMC (PS SD0). The
kernel command line in the device tree mounts `root=/dev/mmcblk1p2`. The
**boot-mode DIP switch must select SD** (`4 3 2 1 = 0 1 0 1`, ON side = 0).

On first boot, `rk-firstboot.service` grows `mmcblk1p2` + the ext4 to fill the
whole card, then disables itself.

## 5. Networking & SSH

`systemd-networkd` runs DHCP on the GEM3 interface (`end0`/`eth0`). `openssh-server`
is enabled, so once the board has an address you can `ssh riguke@<ip>`. The
secondary PL Ethernet (`gem0` → `gmii_to_rgmii` → second RTL8211F) only appears
when a PL bitstream containing that core is loaded.

## 6. Toolchain versions

| component | version / tag |
|-----------|---------------|
| Vivado / Vitis / XSCT / bootgen | 2025.2 |
| u-boot-xlnx, arm-trusted-firmware, linux-xlnx | `xilinx-v2025.2` |
| device-tree-xlnx | `xlnx_rel_v2025.2` |
| Linux kernel | 6.12 |
| U-Boot defconfig | `xilinx_zynqmp_virt_defconfig` |

All overridable through `scripts/env.sh` (`XILINX_VERSION`, `UPSTREAM_TAG`,
`DTX_BRANCH`).
