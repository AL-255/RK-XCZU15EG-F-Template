#!/usr/bin/env bash
#
# scripts/env.sh - shared environment for every build step in this template.
# Source it; do not execute.  Everything is overridable from the caller's env.
#
# shellcheck disable=SC2155

# --- repo / build layout ------------------------------------------------------
export ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export BUILD_DIR="${BUILD_DIR:-$ROOT/build}"     # all build artefacts (git-ignored)
export SRC_DIR="${SRC_DIR:-$BUILD_DIR/src}"      # cloned upstream sources
export OUT_DIR="${OUT_DIR:-$BUILD_DIR/out}"      # final deliverables (BOOT.BIN, Image, *.img)
mkdir -p "$BUILD_DIR" "$SRC_DIR" "$OUT_DIR"

# --- board identity -----------------------------------------------------------
export BOARD="rk-xczu15eg-f"
export FPGA_PART="xczu15eg-ffvb1156-2-i"
export SOC="zynqmp"

# --- toolchain versions -------------------------------------------------------
export XILINX_VERSION="${XILINX_VERSION:-2025.2}"
export XILINX_ROOT="${XILINX_ROOT:-/tools/Xilinx}"
export UPSTREAM_TAG="${UPSTREAM_TAG:-xilinx-v${XILINX_VERSION}}"        # u-boot / atf / linux
export DTX_BRANCH="${DTX_BRANCH:-xlnx_rel_v${XILINX_VERSION}}"          # device-tree-xlnx

# --- cross compiler -----------------------------------------------------------
export ARCH="${ARCH:-arm64}"
export CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"

# --- Debian/Ubuntu rootfs defaults (override in rootfs/build_rootfs.sh call) --
export ROOTFS_DISTRO="${ROOTFS_DISTRO:-debian}"      # debian | ubuntu
export ROOTFS_SUITE="${ROOTFS_SUITE:-bookworm}"      # debian:bookworm/trixie | ubuntu:noble/jammy
export ROOTFS_HOSTNAME="${ROOTFS_HOSTNAME:-rk-xczu15eg-f}"
export ROOTFS_USER="${ROOTFS_USER:-riguke}"
export ROOTFS_PASS="${ROOTFS_PASS:-riguke}"
export ROOTFS_ROOTPASS="${ROOTFS_ROOTPASS:-root}"

# --- source the Xilinx tools if available (xsct / bootgen / vivado) -----------
xilinx_settings() {
    local v="$XILINX_ROOT/$XILINX_VERSION"
    # The Xilinx settings scripts reference unset vars (PYTHONPATH, LD_LIBRARY_PATH);
    # relax nounset while sourcing them, then restore the caller's setting.
    local _u; case $- in *u*) _u=1;; *) _u=0;; esac
    set +u
    # Vitis settings pulls in xsct + bootgen; Vivado settings pulls in vivado.
    [ -f "$v/Vitis/settings64.sh" ]  && source "$v/Vitis/settings64.sh"
    [ -f "$v/Vivado/settings64.sh" ] && source "$v/Vivado/settings64.sh"
    [ "$_u" = 1 ] && set -u
    return 0
}
# Only source on demand so plain image/rootfs steps don't need Xilinx tools.
case " $* " in *" --with-xilinx "*) xilinx_settings;; esac

log()  { printf '\033[1;32m>> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mXX %s\033[0m\n' "$*" >&2; exit 1; }
