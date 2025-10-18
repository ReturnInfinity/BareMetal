# Debugging


## Prerequisites

This document expects the reader to understand some basic fundamentals about x86-64 assembly instructions and hexadecimal notation.

This document was written while using an Ubuntu 25.04 virtual machine within VirtualBox.


## Debugging with GDB

This section deals with debugging in [GDB](https://www.gnu.org/software/gdb/).


### Terminal 1

Set a 'jmp $' somewhere in the source code.

Start a minimal QEMU BareMetal instance

	qemu-system-x86-64 -s -drive format=raw,file=baremetal_os.img


### Terminal 2

Start the GNU debugger

	gdb

Set our parameters and connect to the local QEMU instance (You can also copy the following lines into `./.gdbinit` to have GDB execute the commands automatically on startup)

	set arch i386:x86-64
	set disassembly-flavor intel
	layout asm
	layout regs
	target remote localhost:1234

Execution will be stopped where you put the 'jmp $' in the code. Take a look at the address of the next instruction and use it for the two lines below.

	break *0xXXXXXXX
	jump *0xXXXXXXX

Stepping

	stepi XXX
	nexti XXX

Setting a watchpoint for changes to memory

	watch *(unsigned char*)0xXXXXX
	watch *(unsigned int*)0xXXXXX

QEMU will now be running the code directly after the `jmp $` you had inserted. After the first `stepi` command is executed you can hit enter to repeat the action and want the CPU step through the assembly code.


### GDB instructions

Dump some memory

	x 0xXXXXX


## Debugging with QEMU

When the kernel is compiled a file called `kernel-debug.txt` is generated. This file can be used as a reference for opcode addresses within the kernel. Add `0x100000` to any address in the text file for the actual in-memory address.

Start QEMU with the `-S` switch to start the virtual machine in a paused mode if you need to add a breakpoint somewhere in the kernel startup code. You can un-pause the execution by typing `c` into GDB after you create the breakpoint.


### The QEMU monitor

QEMU has a built in monitor to allow you to query the state of the VM. Running BareMetal via `./baremetal.sh run` in `BareMetal-OS` enables the monitor telnet port.

	telnet localhost 8086


### Debugging via QEMU monitor

Some useful commands:

	info version		QEMU version (latest as of the writing of this doc was 8.0.2)
	info registers		the CPU registers
	info cpus		list the CPUs
	info mem		list the active virtual memory mappings
	info block		block devices such as hard drives, floppy drives, cdrom
	info blockstats		read and write statistics on block devices
	info pci		list pci information
	info network		list network information

Dumping memory:

The 'x' command dumps virtual memory and the 'xp' command dumps physical memory. It takes a format option via '/' as well as a memory address.

Example:

	xp /8xb 0x100000

Dump 8 bytes in hexadecimal format starting at address 0x100000

The "count" parameter is the number of items to be dumped.
The "format" can be x (hex), d (signed decimal), u (unsigned decimal), o (octal), c (char) or i (assembly instruction).
The "size" parameter can be b (8 bits), h (16 bits), w (32 bits) or g (64 bits).


## Capturing QEMU network traffic

Add the following to the network definition

	-net dump,file=net.pcap


## Connecting two QEMU VMs via network

VM 1

	-net socket,listen=:30000

VM 2

	-net socket,connect=:30000


// EOF
