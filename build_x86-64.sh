#!/bin/bash

export topdir=$(pwd)

cd Pure64/
./build.sh
cp multiboot.sys ../
cp pure64.sys ../
cd ..

cd src/x86-64/
nasm kernel.asm -o ../../kernel.sys -l ../../kernel-debug.txt
cd ../..

cd BMFS/
MAKEFLAGS="NO_FUSE=1 NO_UNIX_UTILS=1"
make $MAKEFLAGS
make $MAKEFLAGS install PREFIX=$topdir
cd ..

cd Alloy/
./build.sh
cp alloy.bin ../
cd ..

cat multiboot.sys pure64.sys kernel.sys alloy.bin > boot.bin
