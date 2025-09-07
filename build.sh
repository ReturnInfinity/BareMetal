#!/usr/bin/env bash

BUILDFLAGS=""

# Internal
# -dNO_VIRTIO	Remove VirtIO drivers (NVS, NET)
# NVS
# -dNO_NVME	Remove NVMe driver
# -dNO_AHCI	Remove ACHI (SATA) driver
# -dNO_ATA	Remove legacy ATA driver
# NET
# -dNO_I8254X	Remove i8254x Gigabit driver
# -dNO_I8257X	Remove i8257x Gigabit driver
# -dNO_I8259X	Remove i8259x 10-Gigabit driver
# HID
# -dNO_XHCI	Remove xHCI USB driver (hid)

mkdir -p bin
cd src
nasm $BUILDFLAGS kernel.asm -o ../bin/kernel.sys -l ../bin/kernel-debug.txt
cd ..
