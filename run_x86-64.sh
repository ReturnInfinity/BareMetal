#!/bin/bash

qemu-system-x86_64 -machine q35 -cpu core2duo -smp 2 -m 256 -curses -kernel ./boot.bin -s
