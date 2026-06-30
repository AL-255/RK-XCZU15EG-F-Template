#!/usr/bin/env bash
#
# fetch_sources.sh - clone the upstream Xilinx sources this template builds from.
# Shallow clones of the release tag matching $XILINX_VERSION (default 2025.2).
# Re-running is cheap: existing checkouts are left untouched.
#
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/env.sh"

clone() { # <url> <ref> <dir>
    local url="$1" ref="$2" dir="$SRC_DIR/$3"
    if [ -d "$dir/.git" ]; then log "$3 already present ($dir)"; return; fi
    log "Cloning $3 @ $ref"
    git clone --depth 1 -b "$ref" "$url" "$dir"
}

clone https://github.com/Xilinx/arm-trusted-firmware.git "$UPSTREAM_TAG"  atf
clone https://github.com/Xilinx/u-boot-xlnx.git          "$UPSTREAM_TAG"  u-boot
clone https://github.com/Xilinx/linux-xlnx.git           "$UPSTREAM_TAG"  linux
clone https://github.com/Xilinx/device-tree-xlnx.git     "$DTX_BRANCH"    device-tree-xlnx

log "Sources are in $SRC_DIR"
