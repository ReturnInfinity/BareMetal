x86-64
======

Targeting x86-64 based systems (Intel and AMD)

Building
--------

	./build_x86-64.sh


Running in QEMU
---------------

	qemu-system-x86_64 -machine q35 -cpu core2duo -smp 2 -m 1024 -kernel ./boot.bin


Debugging
---------

This short segment deals with debugging in GDB.


Terminal 1
==========

Set a 'jmp $' somewhere in the source code.

	./build_x86-64.sh

	qemu-system-x86_64 -machine q35 -cpu core2duo -smp 2 -m 1024 -kernel ./boot.bin -s


Terminal 2
===========

Start the GNU debugger

	gdb

Set our parameters and connect to the local QEMU instance

	set arch i386:x86-64
	set disassembly-flavor intel
	layout asm
	layout regs
	target remote localhost:1234

Execution will be stopped where you put the 'jmp $' in the code. Take a look at the address of the next instruction and use it for the two lines below.

	break *0xXXXXXXX
	jump *0xXXXXXXX

	stepi

Dump some memory

	x 0xXXXXX
