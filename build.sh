#!/usr/bin/env bash

mkdir -p bin
cd src
nasm kernel.asm -o ../bin/kernel.sys -l ../bin/kernel-debug.txt
cd ..
