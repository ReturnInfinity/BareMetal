# x86-64

Targeting x86-64 based systems (Intel and AMD)


## Debugging

This short segment deals with debugging in GDB.


### Terminal 1

Set a 'jmp $' somewhere in the source code.

	./build_x86-64.sh

	qemu-system-x86_64 -machine q35 -cpu core2duo -smp 2 -m 256 -curses -kernel ./boot.bin -s


### Terminal 2

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


## Running via the terminal

Start QEMU with the `-curses` option to disable QEMU screen output via SDL. This is useful for testing the VM via a shell session.

Escape+2 will switch to the QEMU monitor console and Escape+1 will switch back to the VM. Enter `quit` on the QEMU monitor console to stop the VM.

## Debugging via QEMU monitor

Some useful commands:

	info registers
	info cpus
	info mem

Dumping memory:

	xp /2xg 0x100000

Dump 2 items in hex (x) 64-bits each (g) starting at address 0x100000
