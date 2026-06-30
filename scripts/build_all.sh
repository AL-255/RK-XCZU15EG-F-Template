#!/usr/bin/env bash
#
# build_all.sh - end-to-end build of the RK-XCZU15EG-F SD image.
# Convenience wrapper around the individual steps; equivalent to `make all`.
#
#   ./scripts/build_all.sh
#
# Honours the same env vars as the per-step scripts (BUILD_DIR, ROOTFS_DISTRO,
# XSA, BITSTREAM, ...).  Source the Xilinx 2025.2 settings first for the
# hardware / boot / device-tree steps.
#
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "$HERE/env.sh"

log "[1/6] fetch sources";   "$HERE/fetch_sources.sh"
log "[2/6] device tree";     "$ROOT/board/device-tree/gen_devicetree.sh"
log "[3/6] boot chain";      "$ROOT/boot/build_boot.sh" "${BITSTREAM:-}"
log "[4/6] kernel";          "$ROOT/linux/build_kernel.sh"
log "[5/6] rootfs";          "$ROOT/rootfs/build_rootfs.sh"
log "[6/6] sd image";        "$ROOT/image/make_sdcard.sh"

log "DONE -> $OUT_DIR/sdcard.img"
