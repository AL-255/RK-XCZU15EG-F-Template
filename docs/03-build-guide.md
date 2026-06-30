# RK-XCZU15EG-F — Build Guide

**Device:** XCZU15EG-FFVB1156-2-I (Zynq UltraScale+ MPSoC)
**Board:** RK-XCZU15EG-F
**Host:** x86-64 Linux

This is the step-by-step recipe for turning this repo into a bootable
Debian/Ubuntu micro-SD image. Every stage is a script under the matching
sub-directory and is also wired to a `make` target. All scripts source
`scripts/env.sh`, which fixes the build layout:

| variable | default | meaning |
|----------|---------|---------|
| `BUILD_DIR` | `./build` | all build artefacts (git-ignored) |
| `SRC_DIR`   | `$BUILD_DIR/src` | cloned upstream sources |
| `OUT_DIR`   | `$BUILD_DIR/out` | deliverables (`BOOT.BIN`, `Image`, `system.dtb`, `*.img`) |

Override any on the command line, e.g. `make all BUILD_DIR=/scratch/rk`. `env.sh`
also fixes the board identity (`BOARD=rk-xczu15eg-f`,
`FPGA_PART=xczu15eg-ffvb1156-2-i`, `XILINX_VERSION=2025.2`,
`CROSS_COMPILE=aarch64-linux-gnu-`). Sourcing it with `--with-xilinx` additionally
sources Vitis then Vivado `settings64.sh` from `XILINX_ROOT/$XILINX_VERSION`
(default `/tools/Xilinx`); the hardware, device-tree and boot stages do this.

> **One-shot:** if you just want an image, jump to [§10](#10-one-shot-make-all)
> and run `make all`.

## 0. Prerequisites & host packages

You need a Vivado / Vitis / XSCT **2025.2** install only for the hardware,
device-tree, FSBL/PMUFW and `bootgen` stages. The kernel, rootfs and SD-image
stages need no Xilinx tools at all.

Install the host packages (the rootfs/image stages are the demanding ones):

```bash
sudo apt-get install -y \
  mmdebstrap debootstrap qemu-user-binfmt binfmt-support \
  mtools dosfstools gdisk u-boot-tools device-tree-compiler \
  gcc-aarch64-linux-gnu build-essential bison flex libssl-dev \
  swig libgnutls28-dev bc cpio rsync xz-utils zstd uidmap
```

Notes:

- `uidmap` provides `/etc/subuid` / `/etc/subgid` ranges — required for the
  rootless rootfs and SD-image steps.
- `qemu-user-binfmt` + `binfmt-support` must leave the **aarch64** handler
  registered with the **`F` (fix-binary)** flag, so it survives entering the
  unshare mount namespace. Check with
  `cat /proc/sys/fs/binfmt_misc/qemu-aarch64`.
- On **Ubuntu 24.04+** unprivileged user namespaces are restricted by AppArmor;
  enable them once per boot before the rootfs/sdcard steps (make it permanent
  via `/etc/sysctl.d/`, or run those steps under `sudo`):
  ```bash
  sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
  ```

For hardware/boot the Xilinx tools must be on `PATH`; the relevant scripts source
`env.sh --with-xilinx` (Vitis then Vivado `settings64.sh`) for you.

## 1. Clone / fetch the upstream sources

```bash
make sources          # == scripts/fetch_sources.sh
```

This shallow-clones the matching release of the Xilinx forks into `$SRC_DIR`:

| source | repo | ref |
|--------|------|-----|
| `atf`              | Xilinx/arm-trusted-firmware | `xilinx-v2025.2` |
| `u-boot`           | Xilinx/u-boot-xlnx          | `xilinx-v2025.2` |
| `linux`            | Xilinx/linux-xlnx           | `xilinx-v2025.2` |
| `device-tree-xlnx` | Xilinx/device-tree-xlnx     | branch `xlnx_rel_v2025.2` |

Re-running is cheap: existing checkouts are left untouched.

## 2. Hardware: regenerate the XSA, or use the bundled golden one

**You usually do NOT need this step.** The device-tree and boot stages default to
the factory golden hand-off `board/hw-handoff/IMAGE_15EG.xsa`, and `make all`
does **not** build hardware. Regenerate only when you change the PL design.

```bash
make hw               # full impl + bitstream (mode = all)
make hw MODE=xsa      # synth only -> XSA (fast; enough for FSBL / device tree)
```

`hw/build_hw.sh [xsa|all]` runs Vivado in batch on `hw/create_project.tcl`,
which builds the block design from `board/XCZU15EG_Base_Config.tcl`, adds EMIO
GPIO plus an example AXI-GPIO, then synthesises (`xsa`) or fully implements and
generates the bitstream (`all`, the default). Outputs land as
`$OUT_DIR/system.xsa` (and `$OUT_DIR/system.bit` for `all`); requires Vivado.
To feed a custom XSA into the next stages, pass `XSA=…/system.xsa` to the
device-tree and boot scripts.

## 3. Device tree

```bash
make devicetree       # == board/device-tree/gen_devicetree.sh
```

Uses XSCT + `device-tree-xlnx` to generate the base device tree from the XSA
(default `board/hw-handoff/IMAGE_15EG.xsa`; override with `XSA=…`), then layers
`board/device-tree/system-user.dtsi` on top and flattens it. It compiles with
`dtc -@` so `__symbols__` are kept — runtime device-tree overlays (e.g. PL
bitstream loading against `&fpga_full`) can resolve labels against the live
tree. Output: **`$OUT_DIR/system.dtb`**. Requires Vitis/XSCT and the fetched
`device-tree-xlnx` (step 1).

## 4. Boot chain → BOOT.BIN

```bash
make boot                          # BOOT.BIN with NO bitstream (default)
make boot BITSTREAM=/path/to.bit   # embed a PL bitstream in BOOT.BIN
```

`boot/build_boot.sh [bitstream]` runs four sub-scripts in order:

1. `build_fsbl_pmufw.sh` — XSCT app build of the `zynqmp_fsbl` and PMU firmware
   from the XSA → `fsbl.elf`, `pmufw.elf`.
2. `build_atf.sh` — `make PLAT=zynqmp … bl31` → `bl31.elf`.
3. `build_uboot.sh` — `xilinx_zynqmp_virt_defconfig` → `u-boot.elf`, plus
   `mkimage` of `boot/boot.cmd` → `boot.scr`.
4. `make_boot_bin.sh` — `bootgen` assembles FSBL → PMUFW → BL31 → U-Boot into
   `$OUT_DIR/BOOT.BIN`.

By **default BOOT.BIN contains no bitstream**: the PL is left unconfigured at
power-up and programmed later from Linux via the FPGA manager (see
`docs/04-bitstream-from-ps.md`). Pass a `.bit` path to have the FSBL pre-load it.

Outputs: `$OUT_DIR/BOOT.BIN` and `$OUT_DIR/boot.scr` (plus the intermediate
ELFs). Requires Vitis/`bootgen` and the cross toolchain.

## 5. Kernel

```bash
make kernel           # == linux/build_kernel.sh
```

Builds the linux-xlnx kernel (6.12). It starts from the `xilinx_defconfig`
defconfig and merges `linux/config/rk-xczu15eg-f.cfg`, which enables the drivers
this board relies on: FPGA manager / FPGA region / OF overlay / configfs,
Realtek **RTL8211F** PHY, Cadence **macb** GEM, Arasan **SDHCI**, ZynqMP
**gqspi** NOR, and **ext4 built-in** (so root mounts without an initramfs).

Outputs: **`$OUT_DIR/Image`** and **`$OUT_DIR/modules.tar.zst`** (the module
tree, overlaid into the rootfs at SD-image assembly time). Cross toolchain only;
no Xilinx tools needed. This is one of the two long stages.

## 6. Root filesystem (Debian / Ubuntu)

```bash
make rootfs                                      # Debian bookworm (default)
make rootfs ROOTFS_DISTRO=ubuntu ROOTFS_SUITE=noble   # Ubuntu noble instead
```

`rootfs/build_rootfs.sh` runs **`mmdebstrap --mode=unshare`** (rootless) to build
a real, `apt`-capable arm64 Debian or Ubuntu system as a tarball
**`$OUT_DIR/rootfs.tar.zst`**. It installs `openssh-server`, `sudo`,
`systemd-networkd` (DHCP on the GEM3 port), a serial getty on `ttyPS0`, sets the
hostname / passwords / user, applies `rootfs/overlay/`, and enables a first-boot
rootfs-resize service (`rk-firstboot.service`). The archive keyring is
auto-resolved (host `/usr/share/keyrings`, else fetched).

Default identity (from `env.sh`): hostname `rk-xczu15eg-f`, user
`riguke` / `riguke`, root password `root`. Override with
`ROOTFS_HOSTNAME` / `ROOTFS_USER` / `ROOTFS_PASS` / `ROOTFS_ROOTPASS`.

**Caveats — read these if the build fails:**

- **User namespaces** must be usable (see §0; Ubuntu 24.04 sysctl) or
  `mmdebstrap --mode=unshare` cannot start.
- **TMPDIR must be on the root filesystem.** `--mode=unshare` creates a *mount*
  namespace that cannot see secondary/USB mounts. The build runs in `TMPDIR`
  (default `/var/tmp`) and streams the tarball out; if `$BUILD_DIR` is on
  another disk, point `TMPDIR` (or `ROOTFS_TMPDIR`) at a roomy directory on `/`.
- The aarch64 **qemu binfmt** handler must be registered (§0); every package
  runs its maintainer scripts under emulation, so this stage — alongside the
  kernel — dominates total build time.

## 7. SD-card image

```bash
make sdcard           # == image/make_sdcard.sh
```

A fully rootless assembler that produces **`$BUILD_DIR/out/sdcard.img`** (MBR):

- **p1 — FAT32 "BOOT" (512 MB):** built with `mtools` (`mformat`/`mcopy`),
  containing `BOOT.BIN`, `Image`, `system.dtb`, `boot.scr`.
- **p2 — ext4 "rootfs" (remainder):** built with `mke2fs -d` inside
  `unshare --user --map-auto --map-root-user`, extracting `rootfs.tar.zst` and
  `modules.tar.zst` so file ownership is recorded correctly without `sudo`.

The MBR partition table is written with `sfdisk` and the two partitions are
`dd`'d into the final image. (Same user-namespace requirement as §6.)

## 8. Flash & first boot

Flash the image to your card (replace `/dev/sdX` with the real device):

```bash
sudo dd if=build/out/sdcard.img of=/dev/sdX bs=4M conv=fsync status=progress
```

Set the **boot-mode DIP switch to SD (SD1)** — switches `4 3 2 1 = 0 1 0 1`,
remembering **ON side = 0**. Insert the card and power on.

- **Serial console:** PS UART0 → USB-UART, **115200 8N1**, device `ttyPS0`.
- **Login:** user `riguke` / `riguke`, or `root` / `root`.
- **Network / SSH:** the wired port comes up via DHCP; find the address on the
  serial console (`ip a`) and:
  ```bash
  ssh riguke@<board-ip>
  ```

On first boot, `rk-firstboot.service` grows the ext4 root partition to fill the
card. Change the default passwords once you are in.

## 9. Troubleshooting

**`mmdebstrap` aborts with a user-namespace / `clone3` / "operation not
permitted" error.** Unprivileged user namespaces are disabled — on Ubuntu 24.04+
run `sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0`; otherwise
confirm `uidmap` is installed with `/etc/subuid` + `/etc/subgid` entries, or run
the `rootfs`/`sdcard` steps under `sudo`.

**Keyring / build files "not found" when `$BUILD_DIR` is on a separate mount.**
The unshare mount namespace cannot see secondary/USB mounts, so point `TMPDIR`
(or `ROOTFS_TMPDIR`) at a directory on `/` — the script stages the keyring and
overlay there for exactly this reason.

**`qemu-aarch64 binfmt not registered`.** Install `qemu-user-binfmt` +
`binfmt-support`, verify `/proc/sys/fs/binfmt_misc/qemu-aarch64` exists with the
`F` flag, and if needed `sudo systemctl restart systemd-binfmt`.

**No `/dev/fpga*` / bitstream loading fails on the board.** The FPGA manager
must be in the kernel; it comes from `linux/config/rk-xczu15eg-f.cfg`
(`CONFIG_FPGA_MGR_ZYNQMP_FPGA`, `CONFIG_OF_FPGA_REGION`, `CONFIG_OF_OVERLAY`,
`CONFIG_CONFIGFS_FS`). If you replaced the defconfig or skipped the fragment
merge, rebuild the kernel (§5) so the fragment is applied.

**`vivado` / `xsct` / `bootgen` not found.** Source the Xilinx `settings64.sh`
(§0); those stages source `env.sh --with-xilinx` and read
`XILINX_ROOT/$XILINX_VERSION` — adjust either if your install lives elsewhere.

## 10. One-shot: `make all`

```bash
make all
# -> build/out/sdcard.img
```

`make all` runs **sources → devicetree → boot → kernel → rootfs → sdcard** in
order (it uses the golden `IMAGE_15EG.xsa`; it does **not** run `make hw`). You
still need the Xilinx tools sourced and the host packages from §0. Wall-clock
time is dominated by the **kernel** build and the **qemu-emulated rootfs** build.

Other Makefile targets: `sources`, `hw`, `devicetree`, `boot`, `kernel`,
`rootfs`, `sdcard`, `all`, `clean` (wipe `out/` + intermediate hw/fsbl/dt
dirs), `distclean` (wipe `$BUILD_DIR`).
