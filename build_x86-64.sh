#!/bin/bash

cd src/x86-64/loader/
nasm loader.asm -o ../../../loader.sys
cd ../../..

cd src/x86-64/loader/bootsectors/
nasm multiboot.asm -o ../../../../multiboot.sys
cd ../../../..

cd src/x86-64/kernel/
nasm kernel.asm -o ../../../kernel.sys
cd ../../..

cat multiboot.sys loader.sys kernel.sys > boot.bin
