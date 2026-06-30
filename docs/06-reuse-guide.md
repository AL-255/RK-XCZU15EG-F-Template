# Reusing This Template for a New XCZU15EG Project

This guide is for an engineer starting a **new** project from the RK-XCZU15EG-F BSP
template. The board is the same silicon (XCZU15EG-FFVB1156-2-I) and the same carrier;
what changes between projects is almost always **your PL design** and **your software**,
not the board definition.

## Mental model

- **`board/` *is* the board.** PS preset, PL pin constraints, base device tree, and the
  golden hand-off all describe the physical RK-XCZU15EG-F. Reuse it as-is. You only touch
  it when the *hardware wiring you use* changes (new PL pins, different PHY, different PS
  peripheral usage).
- **Everything else is "how to build software for that board."** `hw/` generates a
  Vivado design, `boot/`/`linux/`/`rootfs/`/`image/` turn it into a bootable card,
  `scripts/` is shared plumbing. These are generic and rarely change per project.

A new project is mostly: drop your IP into `hw/create_project.tcl`, add your pins to
`board/constraints/`, rebuild, point the device tree and boot at the new XSA.

## Keep / Edit / Regenerate

| Directory / file | Default action | When you touch it |
|---|---|---|
| `board/XCZU15EG_Base_Config.tcl` | **Keep** | Only if you change PS peripheral usage (enable/disable a MIO peripheral, change DDR, clocks). |
| `board/constraints/*.xdc` | **Edit** | Add the top-level ports your PL design drives. Existing blocks are copy-as-needed. |
| `board/device-tree/system-user.dtsi` | **Keep / Edit** | Edit when PL wiring changes (e.g. remove the `&psu_ethernet_0_mdio`/`phy1` block if your bitstream has no `gmii_to_rgmii` core). |
| `board/device-tree/gen_devicetree.sh` | **Keep** | Generic XSA → DT flow. |
| `board/hw-handoff/` | **Keep** | Factory reference/fallback XSA + bitstream + `psu_init`. Don't overwrite. |
| `hw/create_project.tcl` | **Edit** | Put your IP in the `USER PL LOGIC` section. This is the main per-project file. |
| `hw/build_hw.sh` | **Keep** | Generic Vivado batch wrapper. |
| `boot/`, `linux/`, `image/` | **Keep** | Generic. |
| `rootfs/` | **Edit (light)** | Add packages (`PKGS`), files (`overlay/`), first-boot logic. |
| `scripts/env.sh` | **Edit (light)** | Board identity + tool versions / rootfs defaults. |
| `build/` | **Regenerate** | Git-ignored; produced by the scripts. Never commit. |

---

## 1. Fork the template

```bash
cp -a RK-XCZU15EG-F-Template my-new-project      # or: git clone / degit
cd my-new-project
rm -rf build .Xil                                # drop generated + tool noise
git init && git add -A && git commit -m "Fork RK-XCZU15EG-F BSP template"
git remote add origin <your-remote> && git push -u origin main
```

Keep `board/` intact — it is the value of the template. If you want a different board
name in artefacts/hostname, edit `BOARD` and the `ROOTFS_HOSTNAME` default in
`scripts/env.sh`. The part number lives in two places: `FPGA_PART` in `scripts/env.sh`
and `PART` in `hw/create_project.tcl` (leave both as `xczu15eg-ffvb1156-2-i` for this
board).

---

## 2. Add your own PL design

### a. Edit the Vivado generator + constraints

Open `hw/create_project.tcl` and replace the example in the `USER PL LOGIC` section
(an AXI-GPIO plus the exported EMIO GPIO) with your IP. The pattern to follow:

```tcl
# 1. instantiate your IP
set my_ip [create_bd_cell -type ip -vlnv <vendor:lib:name:ver> my_ip_0]
set_property -dict [list CONFIG.SOME_PARAM {value}] $my_ip

# 2. connect it to the PS via the general-purpose AXI master, clocks/resets auto-wired
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config \
    [list Master "/zynq_ultra_ps_e_0/M_AXI_HPM0_FPD" Clk "Auto"] \
    [get_bd_intf_pins $my_ip/S_AXI]

# 3. surface any fabric I/O as external ports (names must match the XDC)
make_bd_pins_external [get_bd_pins $my_ip/<your_output>]
```

Notes:
- `M_AXI_HPM0_FPD` is the PS GP0 master (already enabled near the top of the script via
  `CONFIG.PSU__USE__M_AXI_GP0`). The 100 MHz `pl_clk0` is enabled there too. If you need
  more AXI masters, a wider data path, or more PL clocks, set the relevant
  `CONFIG.PSU__*` keys in that same block.
- Keep the EMIO GPIO export (`$ps/GPIO_0`) — the base device tree maps the on-board
  PL LEDs/keys (gpio 78..93) onto it.
- Add your top-level port pins to `board/constraints/rk-xczu15eg-f.xdc`. Each block in
  the XDC is self-contained — copy only the blocks whose ports your top-level actually
  drives. PS peripherals are fixed MIO and are **not** in the XDC (they live in the PS
  preset). For a PL-side DDR4/MIG, also pull in `rk-xczu15eg-f-pl-ddr4.xdc`.

Build it:

```bash
make hw MODE=all        # synth + impl + bitstream -> build/hw/rk_xczu15eg_f.{xsa,bit}
# or, just the XSA (fast, enough for FSBL + device tree, no bitstream):
make hw MODE=xsa
```

`build_hw.sh` also copies the newest results to `build/out/system.xsa` and
`build/out/system.bit` for convenience.

### b. Point the device tree + boot at the new XSA

```bash
make devicetree XSA=build/hw/rk_xczu15eg_f.xsa     # -> build/system.dtb (+ build/out/system.dtb)
make boot                                          # FSBL/PMUFW/ATF/U-Boot -> BOOT.BIN
```

`gen_devicetree.sh` reads `XSA` from the environment (default: the factory hand-off
`board/hw-handoff/IMAGE_15EG.xsa`), runs the Xilinx generator, then layers
`board/device-tree/system-user.dtsi` on top.

**Custom AXI IP usually needs device-tree nodes.** Two options:
- **Regenerate (preferred):** the generator emits `pl.dtsi` *from your XSA*, so memory-
  mapped AXI IP it recognizes is picked up automatically. Just rerun `make devicetree`
  with your new `XSA=`.
- **Hand-write:** add nodes to `board/device-tree/system-user.dtsi` for anything the
  generator doesn't model (custom registers, your own driver's `compatible`, fixups).
  The DTB is built with `dtc -@`, so `__symbols__` are kept and runtime overlays can
  resolve labels.

Then finish the image as usual:

```bash
make kernel rootfs sdcard
```

---

## 3. Load your bitstream at runtime from Linux

The template deliberately ships a **bitstream-free `BOOT.BIN`** so the PL stays yours to
program at run time (no JTAG, no reboot). To use that flow:

```bash
scripts/bit2bin.sh my_design.bit          # -> my_design.bit.bin (raw, FPGA-manager loadable)
scp my_design.bit.bin riguke@<board-ip>:/lib/firmware/
# on the board:
sudo load-bitstream.sh /lib/firmware/my_design.bit.bin
sudo load-bitstream.sh --status           # expect fpga manager state "operating"
```

`load-bitstream.sh` (installed from `rootfs/overlay/usr/local/bin/`) loads through the
ZynqMP FPGA manager via a `&fpga_full` overlay. See `docs/04-bitstream-from-ps.md` for
the full flow and partial-reconfiguration notes.

If you instead want the PL fixed at boot, embed it in `BOOT.BIN`:

```bash
make boot BITSTREAM=build/hw/rk_xczu15eg_f.bit
```

Pick one model per project: keep `BOOT.BIN` bitstream-free for run-time loading, **or**
embed with `BITSTREAM=` for a fixed PL at power-on.

---

## 4. Change the rootfs

All knobs live in `scripts/env.sh` (overridable on the `make` line) and in
`rootfs/build_rootfs.sh`:

- **Distro / suite:**
  ```bash
  make rootfs ROOTFS_DISTRO=ubuntu ROOTFS_SUITE=noble   # or debian bookworm/trixie
  ```
- **Add packages:** append to the `PKGS` list in `rootfs/build_rootfs.sh` (comma-
  separated apt names). It already installs ssh, sudo, i2c-tools, can-utils, gpiod, etc.
- **Add files (configs, scripts, units):** drop them under `rootfs/overlay/` at their
  final on-target path (e.g. `rootfs/overlay/etc/...`). The overlay is copied verbatim
  into `/` during the build.
- **First-boot logic:** the template already wires a `rk-firstboot.service`
  (`rootfs/overlay/etc/systemd/system/`) running `rk-firstboot.sh`
  (`rootfs/overlay/usr/local/sbin/`) for rootfs expansion + firmware dir. Add your own
  one-shot setup the same way: a script in the overlay plus a systemd unit enabled in the
  in-chroot `configure.sh` block of `build_rootfs.sh`.

---

## 5. Change PS peripheral usage

If your project enables/disables a PS peripheral, changes DDR size, or retimes a clock,
the source of truth is the **PS preset**, `board/XCZU15EG_Base_Config.tcl`:

- Cleanest: re-open the design in Vivado, change the PS config in the Zynq UltraScale+
  block, and **re-export the preset tcl** to replace `XCZU15EG_Base_Config.tcl`.
- Quick tweak: set the specific `CONFIG.PSU__*` key in the post-preset block of
  `hw/create_project.tcl` (this is how the template already forces EMIO GPIO and the GP0
  master on).

Either way, **regenerate the device tree afterwards** (`make devicetree XSA=...`) so the
`pcw.dtsi`/`psu_init` side matches the new MIO/peripheral set, and rebuild `boot`
(the FSBL/`psu_init` is derived from the XSA).

---

## 6. Version to a different Xilinx release

Tool/source versions are centralized in `scripts/env.sh`:

| Variable | Controls | Default |
|---|---|---|
| `XILINX_VERSION` | Vivado/Vitis/XSCT toolchain | `2025.2` |
| `UPSTREAM_TAG` | u-boot / ATF / linux tag | `xilinx-v$XILINX_VERSION` |
| `DTX_BRANCH` | `device-tree-xlnx` branch | `xlnx_rel_v$XILINX_VERSION` |

To move to another release, source that Vivado/Vitis `settings64.sh` and override the
vars — either edit `scripts/env.sh` or pass them in the environment:

```bash
XILINX_VERSION=2024.2 make sources hw devicetree boot
```

`UPSTREAM_TAG`/`DTX_BRANCH` derive from `XILINX_VERSION` unless you set them explicitly
(useful when upstream tag names don't track the tool version). Re-run `make sources` so
the clones land on the new tag/branch.

---

## 7. Checklist for a new board variant

For a relative of this board (same SoC family, different carrier wiring):

- **Different DDR size / speed:** change the DDR settings in the PS preset
  (`board/XCZU15EG_Base_Config.tcl`), then `make devicetree boot`. Update the figures in
  `docs/01-board-overview.md`.
- **Different PHY / PHY address:** edit the PHY node(s) in
  `board/device-tree/system-user.dtsi` (the `phy@N` reg, `compatible`, `phy-mode`). If the
  variant has no PL `gmii_to_rgmii` core, delete the `&psu_ethernet_0_mdio`/`phy1` block.
- **Different boot media:** boot order follows the DIP switch (SD1 / QSPI32 / eMMC SD0 /
  JTAG); the rootfs `fstab`/first-boot expansion in `rootfs/overlay/` assumes the SD path
  — adjust if you boot from eMMC or QSPI.
- **Different part number:** update `FPGA_PART` (`scripts/env.sh`) and `PART`
  (`hw/create_project.tcl`).
- **Different PL pinout:** rebuild `board/constraints/*.xdc` from the new carrier
  schematic.
- **Regenerate everything from clean:** `make distclean && make all` once the above are
  set, and re-verify boot to serial console + Ethernet/SSH.

When in doubt, re-read `docs/02-architecture.md` (who configures what in the boot chain)
before changing anything in `board/`.
