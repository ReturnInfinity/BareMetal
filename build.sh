#!/usr/bin/env bash

BUILDFLAGS="-dNO_VGA"

# Internal
# -dNO_VIRTIO	Remove VirtIO drivers (NVS, NET)
# NVS
# -dNO_NVME	Remove NVMe driver
# -dNO_AHCI	Remove ACHI (SATA) driver
# NET
# -dNO_I8254X	Remove i8254x Gigabit driver
# -dNO_I8257X	Remove i8257x Gigabit driver
# -dNO_I8259X	Remove i8259x 10-Gigabit driver
# HID
# -dNO_XHCI	Remove xHCI USB driver (hid)
# -dNO_LFB	Remove LFB graphical text output driver
# -dNO_VGA	Remove VGA text output driver

mkdir -p bin
cd src
nasm $BUILDFLAGS kernel.asm -o ../bin/kernel.sys -l ../bin/kernel-debug.txt
cd ..
