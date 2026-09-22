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

# 1. Validation and Safety
if [ ! -b "$TARGET_DEV" ]; then
  echo "Error: $TARGET_DEV is not a valid block device."
  exit 1
fi

if [ ! -d "$SYSROOT_DIR" ]; then
  echo "Error: sysroot directory '$SYSROOT_DIR' not found."
  exit 1
fi

# Ensure the sysroot actually contains the compiled EFI binary
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

# Determine partition naming (handle NVMe/loopback vs standard sdX)
if [[ "$TARGET_DEV" == *[0-9] ]]; then
  PARTITION="${TARGET_DEV}p1"
else
  PARTITION="${TARGET_DEV}1"
fi

# 2. Unmount any existing partitions on the target device
echo "Unmounting existing partitions on $TARGET_DEV..."
umount ${TARGET_DEV}* 2>/dev/null || true

# 3. Create a fresh GPT partition table and a single FAT32 partition
echo "Partitioning $TARGET_DEV..."
parted -s "$TARGET_DEV" mklabel gpt
parted -s "$TARGET_DEV" mkpart primary fat32 1MiB 100%
parted -s "$TARGET_DEV" set 1 esp on

# Wait for the OS to recognize the new partition table
sleep 2

# 4. Format the new partition to FAT32
echo "Formatting $PARTITION to FAT32..."
mkfs.fat -F 32 "$PARTITION"

# 5. Mount and mirror the sysroot
echo "Mounting $PARTITION and copying sysroot contents..."
MOUNT_POINT=$(mktemp -d)
mount "$PARTITION" "$MOUNT_POINT"

# Copy everything from sysroot directly into the root of the USB drive
cp -r "$SYSROOT_DIR"/* "$MOUNT_POINT/"

# 6. Cleanup
echo "Syncing data to USB and unmounting..."
sync
umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

echo "Success! The USB drive is ready to boot on physical hardware."