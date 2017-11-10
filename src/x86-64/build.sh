#!/bin/sh

set -e

nasm kernel.asm -o kernel.o -f elf64 -g -F dwarf
ld kernel.o -o kernel.elf -T kernel.ld
objcopy -O binary kernel.elf kernel.bin
