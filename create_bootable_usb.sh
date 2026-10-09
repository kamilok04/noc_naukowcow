#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script requires root privileges to format the USB drive. Run with sudo."
  exit 1
fi

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <target_device> <path_to_sysroot>"
  echo "Example: $0 /dev/sdb ./sysroot"
  exit 1
fi

TARGET_DEV=$1
SYSROOT_DIR=$2

# validate the block device
if [ ! -b "$TARGET_DEV" ]; then
  echo "Error: $TARGET_DEV is not a valid block device."
  exit 1
fi

if [ ! -d "$SYSROOT_DIR" ]; then
  echo "Error: sysroot directory '$SYSROOT_DIR' not found."
  exit 1
fi

# ensure the sysroot actually contains the compiled EFI binary
if [ ! -f "$SYSROOT_DIR/EFI/BOOT/BOOTX64.EFI" ]; then
  echo "Error: BOOTX64.EFI not found inside $SYSROOT_DIR/EFI/BOOT/. Did you run the CMake build?"
  exit 1
fi

echo "================================================================="
echo "DANGER: This will completely WIPE and format $TARGET_DEV"
echo "Ensure this is your USB drive and NOT your system drive!"
echo "================================================================="
read -p "Type YES in all caps to continue: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
  echo "Aborted."
  exit 1
fi

# determine partition naming (handle NVMe/loopback vs standard sdX)
if [[ "$TARGET_DEV" == *[0-9] ]]; then
  PARTITION="${TARGET_DEV}p1"
else
  PARTITION="${TARGET_DEV}1"
fi

# unmount any existing partitions on the target device
echo "Unmounting existing partitions on $TARGET_DEV..."
umount ${TARGET_DEV}* 2>/dev/null || true

# GPT formatting, FAT32 filesystem
echo "Partitioning $TARGET_DEV..."
parted -s "$TARGET_DEV" mklabel gpt
parted -s "$TARGET_DEV" mkpart primary fat32 1MiB 100%
parted -s "$TARGET_DEV" set 1 esp on

sleep 2
echo "Formatting $PARTITION to FAT32..."
mkfs.fat -F 32 "$PARTITION"

# mount and mirror the sysroot
echo "Mounting $PARTITION and copying sysroot contents..."
MOUNT_POINT=$(mktemp -d)
mount "$PARTITION" "$MOUNT_POINT"

# copy everything from sysroot directly into the root of the USB drive
cp -r "$SYSROOT_DIR"/* "$MOUNT_POINT/"

# cleanup
echo "Syncing data to USB and unmounting..."
sync
umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

echo "Success! The USB drive is ready to boot on physical hardware."