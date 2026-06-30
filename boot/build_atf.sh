#!/usr/bin/env bash
#
# build_atf.sh - build the Arm Trusted Firmware BL31 (EL3 runtime) for ZynqMP.
# BL31 is the secure monitor that sits between U-Boot/Linux (EL2/EL1) and the
# PSCI/SMC services.  It is the third stage in BOOT.BIN.
#
# Output: $OUT_DIR/bl31.elf
#
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../scripts/env.sh"

ATF="${ATF_SRC:-$SRC_DIR/atf}"
[ -d "$ATF" ] || die "ATF source missing - run scripts/fetch_sources.sh"

log "Building ATF BL31 (PLAT=zynqmp)"
make -C "$ATF" -j"$(nproc)" \
     CROSS_COMPILE="$CROSS_COMPILE" \
     PLAT=zynqmp RESET_TO_BL31=1 bl31

cp "$ATF/build/zynqmp/release/bl31/bl31.elf" "$OUT_DIR/bl31.elf"
log "BL31 -> $OUT_DIR/bl31.elf"
