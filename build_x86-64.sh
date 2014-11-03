#!/bin/bash
cd src/x86-64
nasm kernel.asm -o ../../kernel.sys
cd ../..
