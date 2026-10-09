#!/bin/bash
set -e

if [ -z "$USB_DEV" ]; then
    echo "BŁĄD: Ustaw zmienną środowiskową USB_DEV! (np. sudo USB_DEV=/dev/sdX make run_usb)"
    exit 1
fi

if [ ! -b "$USB_DEV" ]; then
    echo "BŁĄD: $USB_DEV nie jest prawidłowym urządzeniem blokowym."
    exit 1
fi

# The first argument passed by CMake will be the BIOS path
BIOS_PATH=$1

echo "Uruchamianie QEMU z dysku: $USB_DEV"

exec qemu-system-x86_64 \
    -cpu qemu64 \
    -bios "$BIOS_PATH" \
    -device qemu-xhci \
    -device usb-mouse \
    -device virtio-rng-pci \
    -display gtk,show-tabs=on \
    -machine q35 \
    -drive file="$USB_DEV",format=raw,if=none,id=usbstick \
    -device usb-storage,drive=usbstick \
    -chardev stdio,id=char0,logfile=serial_usb.log,signal=off \
    -serial chardev:char0