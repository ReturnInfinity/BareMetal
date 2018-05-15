# Debugging with GDB and QEMU

This document deals with debugging in [GDB](https://www.gnu.org/software/gdb/).

## Prerequisites

This document expects the reader to understand some basic fundamentals about x86-64 assembly instructions and hexadecimal notation.

This document was written while using an Ubuntu 18.04 virtual machine within VirtualBox.


## Building a binary for QEMU to boot

The instructions below require the multiboot.bin and pure64.sys binaries from [Pure64](https://github.com/ReturnInfinity/Pure64).

A couple steps need to be completed prior to compiling Pure64!

1. Adjust the Pure64 `multiboot.asm` file to not use graphics. QEMU does not support multiboot graphics mode.

	Change the line ``FLAG_VIDEO		equ 1<<2   ; set video mode`` to `FLAG_VIDEO		equ 0<<2   ; clear video mode`

2. Adjust Pure64 to just start the kernel instead of a stage 3 loader.

	`$ sed -i 's/call STAGE3/jmp 0x100000/g' pure64.asm`

Use the following to build boot.bin:

	cat multiboot.sys pure64.sys kernel.sys > boot.bin


## Debugging with GDB

### Terminal 1

Set a 'jmp $' somewhere in the source code.

	qemu-system-x86_64 -smp 2 -m 256 -serial file:serial.log -curses -kernel ./boot.bin -s


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

	stepi

QEMU will now be running the code directly after the `jmp $` you had inserted. After the first `stepi` command is executed you can hit enter to repeat the action and want the CPU step through the assembly code.


## Debugging with QEMU (at a known address)

When the kernel is compiled a file called `kernel-debug.txt` is generated. This file can be used as a reference for opcode addresses within the kernel. Add `0x100000` to any address in the text file for the actual in-memory address.

Start QEMU with the `-S` switch to start the virtual machine in a paused mode if you need to add a breakpoint somewhere in the kernel startup code. You can un-pause the execution by typing `c` into GDB after you create the breakpoint.


## The QEMU monitor

QEMU has a built in monitor to allow you to query the state of the VM.

`Escape+2` will switch to the QEMU monitor console and `Escape+1` will switch back to the VM. Enter `quit` on the QEMU monitor console to stop the VM.


### Debugging via QEMU monitor

Some useful commands:

	info registers
	info cpus
	info mem

Dumping memory:

	xp /8xb 0x100000

Dump 8 bytes in hexadecimal format starting at address 0x100000


## GDB instructions

Dump some memory

	x 0xXXXXX


## Capturing QEMU network traffic

Add the following to the qemu start command in run_x86_64.sh

	-net nic,model=e1000 -net dump,file=net.pcap


## Connecting two QEMU VMs via network

VM 1

	-net socket,listen=:30000

VM 2

	-net socket,connect=:30000


// EOF