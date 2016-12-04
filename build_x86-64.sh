#!/bin/bash

cd Pure64/
./build.sh
cp src/bootsectors/multiboot.sys ../
cp src/pure64.sys ../
cd ..

cd src/x86-64/
nasm kernel.asm -o ../../kernel.sys
cd ../..

cat multiboot.sys pure64.sys kernel.sys > boot.bin
