#!/usr/bin/env bash

BUILDFLAGS=""

# Internal
# -DNO_VIRTIO=1		Remove VirtIO drivers (NVS, NET)
# NVS
# -DNO_NVME=1		Remove NVMe driver
# -DNO_AHCI=1		Remove ACHI (SATA) driver
# -DNO_ATA=1		Remove legacy ATA driver
# NET
# -DNO_I8254X=1		Remove i8254x Gigabit driver
# -DNO_I8257X=1		Remove i8257x Gigabit driver
# -DNO_I8259X=1		Remove i8259x 10-Gigabit driver
# HID
# -DNO_XHCI=1		Remove xHCI USB driver (hid)

mkdir -p bin
cd src
nasm $BUILDFLAGS kernel.asm -o ../bin/kernel.sys -l ../bin/kernel-debug.txt
cd ..
