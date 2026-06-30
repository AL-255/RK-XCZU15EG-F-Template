# =============================================================================
#  RK-XCZU15EG-F board support package - top-level build
# -----------------------------------------------------------------------------
#  Typical first build:
#     make sources          # clone u-boot / atf / linux / device-tree-xlnx
#     make devicetree boot  # system.dtb + BOOT.BIN  (needs Vivado/Vitis 2025.2)
#     make kernel           # Image + kernel modules
#     make rootfs           # apt-capable Debian/Ubuntu arm64 root filesystem
#     make sdcard           # bootable sdcard.img
#  ...or just:  make all
#
#  Override the build location / target distro on the command line, e.g.:
#     make rootfs ROOTFS_DISTRO=ubuntu ROOTFS_SUITE=noble
#     make all BUILD_DIR=/scratch/rk-build
# =============================================================================
SHELL := /bin/bash
export BUILD_DIR ?= $(CURDIR)/build

.PHONY: help all sources hw devicetree boot kernel rootfs sdcard clean distclean

help:
	@sed -n '2,18p' Makefile | sed 's/^# \{0,1\}//'
	@echo ""
	@echo "Targets: sources hw devicetree boot kernel rootfs sdcard all clean distclean"

all: sources devicetree boot kernel rootfs sdcard
	@echo ">> Full build complete. Image: $(BUILD_DIR)/out/sdcard.img"

sources:        ; scripts/fetch_sources.sh
hw:             ; hw/build_hw.sh $(MODE)
devicetree:     ; board/device-tree/gen_devicetree.sh
boot:           ; boot/build_boot.sh $(BITSTREAM)
kernel:         ; linux/build_kernel.sh
rootfs:         ; rootfs/build_rootfs.sh
sdcard:         ; image/make_sdcard.sh

clean:
	rm -rf $(BUILD_DIR)/out $(BUILD_DIR)/hw $(BUILD_DIR)/fsbl_ws $(BUILD_DIR)/device-tree
distclean:
	rm -rf $(BUILD_DIR)
