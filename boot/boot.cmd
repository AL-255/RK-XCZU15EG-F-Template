# RK-XCZU15EG-F U-Boot boot script  ->  compile with:
#   mkimage -c none -A arm64 -T script -d boot.cmd boot.scr
#
# Loads a flat kernel Image + our board device tree (system.dtb) from the FAT
# boot partition that this script itself was sourced from, then boots.  Falls
# back to a FIT image (image.ub) if present.  Root filesystem is on the SD
# card's second partition (ext4) - see the kernel command line in system.dtb.

setenv kernel_addr   0x18000000
setenv fdt_addr      0x10000000
setenv imageub_addr  0x10000000
setenv bootargs      "earlycon console=ttyPS0,115200 clk_ignore_unused cma=512M root=/dev/mmcblk1p2 rw rootwait"

echo "RK-XCZU15EG-F: booting from ${devtype} ${devnum}:${distro_bootpart}"

if test -e ${devtype} ${devnum}:${distro_bootpart} /Image; then
    fatload ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr} Image
    fatload ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr}    system.dtb
    booti ${kernel_addr} - ${fdt_addr}
    exit
fi

if test -e ${devtype} ${devnum}:${distro_bootpart} /image.ub; then
    fatload ${devtype} ${devnum}:${distro_bootpart} ${imageub_addr} image.ub
    bootm ${imageub_addr}
    exit
fi

echo "RK-XCZU15EG-F: no kernel (Image / image.ub) found on boot partition"
