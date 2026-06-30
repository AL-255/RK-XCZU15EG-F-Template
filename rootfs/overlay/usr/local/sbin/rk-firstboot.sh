#!/bin/sh
# Grow the root partition + filesystem to fill the micro-SD card, once.
set -e
DISK=/dev/mmcblk1
PART=2
DEV=${DISK}p${PART}

[ -b "$DEV" ] || { echo "rk-firstboot: $DEV not found"; exit 0; }

echo "rk-firstboot: growing $DEV to fill $DISK"
if command -v growpart >/dev/null 2>&1; then
    growpart "$DISK" "$PART" || true
else
    # util-linux fallback: extend the last partition to the end of the disk
    echo ", +" | sfdisk --no-reread -N "$PART" "$DISK" || true
fi
partprobe "$DISK" 2>/dev/null || true
resize2fs "$DEV" || true

# Run only once.
systemctl disable rk-firstboot.service 2>/dev/null || true
echo "rk-firstboot: done"
exit 0
