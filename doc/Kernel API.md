# BareMetal x86-64 API

Version 1 - November 16, 2022


### Notes

This document details the API calls built into the BareMetal exokernel.


### Contents

1. Input/Output
	- b\_input
	- b\_output
2. Network
	- b\_net\_tx
	- b\_net\_rx
3. Storage
	- b\_storage\_read
	- b\_storage\_write
4. Misc
	- b\_system


## Input/Output


### b\_input

Scans for input from keyboard or serial.

Assembly Registers:

	 IN:	Nothing
	OUT:	AL = 0 if no key pressed, otherwise ASCII code, other regs preserved
		All other registers preserved

Assembly Example:

	call [b_input]
	mov byte [KeyChar], al
	...
	KeyChar: db 0

C Example:

	char KeyChar;
	KeyChar = b_input();
	if (KeyChar == 'a')
	...


### b\_output

Output a number of characters via the standard output method.

Assembly Registers:

	 IN:	RSI = message location
		RCX = number of characters to output
	OUT:	All registers preserved

Assembly Example:

	mov rsi, Message
	mov rcx, 4
	call [b_output]					; Only output the word 'This'
	...
	Message: db 'This is a test', 0

C Example:

	b_output_chars("This is a test", 4);	// Output 'This'

	char Message[] = "Hello, world!";
	b_output_chars(Message, 5);				// Output 'Hello'


## Network


### b\_net\_tx

Transmit data via a network interface

Assembly Registers:

	 IN:	RSI = memory location of packet
		RCX = length of packet
		RDX = Interface ID
	OUT:	All registers preserved

Assembly Example:

	mov rsi, Packet
	mov rcx, 1500
	mod rdx, 0
	call [b_net_tx]
	...
	Packet:
	Packet_Dest: db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF ; Broadcast
	Packet_Src: db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	Packet_Type: dw 0xABBA
	Packet_Data: db 'This is a test', 0

The packet must contain a proper 14-byte header.


### b\_net\_rx

Receive data via a network interface

Assembly Registers:

	 IN:	RDI = memory location to store packet
		RDX = Interface ID
	OUT:	RCX = length of packet, 0 if nothing to receive

Assembly Example:

	mov rdi, Packet
	mov rdx, 0
	call [b_net_rx]
	...
	Packet: times 1518 db 0

Note: BareMetal does not keep a buffer of received packets. This means that the OS will overwrite the last packet as soon as a new one is received. Continuously polling the network by checking `os_net_rx` often, is possible, but this is not ideal. BareMetal allows for a network interrupt callback handler to be run whenever a packet is received. With a callback, a program will always be aware of when a packet is received.


## Storage

BareMetal uses 4096 byte sectors for all drive access. Drive sectors start at 0.


### b\_storage\_read

Read a number of sectors from a drive to memory

Assembly Registers:

	 IN:	RAX = Starting sector #
	 	RCX = Number of sectors to read
	 	RDX = Drive #
		RDI = Destination memory address
	OUT:	RCX = Number of sectors read
		All other registers preserved

Assembly Example:

	mov rax, 0			; Read sector 0
	mov rcx, 1			; Read one sector
	mov rdx, 0			; Read from drive 0
	mov rdi, buffer			; Read drive data to this memory address
	call [b_storage_read]


### b\_storage\_write

Write a number of sectors from memory to a drive

Assembly Registers:

	 IN:	RAX = Starting sector #
	 	RCX = Number of sectors to write
	 	RDX = Drive #
		RSI = Source memory address
	OUT:	RCX = Number of sectors written
		All other registers preserved

Assembly Example:

	mov rax, 0			; Write to sector 0
	mov rcx, 1			; Write one sector
	mov rdx, 0			; Write to drive 0
	mov rsi, buffer			; Write the contents from this memory address to the drive
	call [b_storage_write]


## Misc


### b\_system

Call system functions

Assembly Registers:

	 IN:	RCX = Function
		RAX = Variable 1
		RDX = Variable 2
	OUT:	RAX = Result 1

Currently the following functions are supported:

#### TIMECOUNTER		equ 0x00
#### FREE_MEMORY		equ 0x02
#### NETWORKCALLBACK_GET	equ 0x03
#### NETWORKCALLBACK_SET	equ 0x04
#### CLOCKCALLBACK_GET	equ 0x05
#### CLOCKCALLBACK_SET	equ 0x06
#### SMP_ID			equ 0x10
	- Returns the APIC ID of the CPU that ran this function
	- out RAX: The ID
#### SMP_NUMCORES		equ 0x11
	- Returns the total number of CPU cores
#### SMP_SET			equ 0x12
#### SMP_GET			equ 0x13
#### SMP_LOCK		equ 0x14
	- Attempt to lock a mutex, this is a simple spinlock
	- in RAX: The address of the mutex (one word)
#### SMP_UNLOCK		equ 0x15
	- Unlock a mutex
	- in RAX: The address of the mutex (one word)
#### SMP_BUSY		equ 0x16
#### SCREEN_LFB_GET		equ 0x20
#### SCREEN_X_GET		equ 0x21
#### SCREEN_Y_GET		equ 0x22
#### SCREEN_PPSL_GET		equ 0x23
#### SCREEN_BPP_GET		equ 0x24
#### MAC_GET			equ 0x30
#### BUS_READ		equ 0x40
#### BUS_WRITE		equ 0x41
#### STDOUT_SET		equ 0x42
#### STDOUT_GET		equ 0x43
#### DUMP_MEM		equ 0x80
	- Dump contents of memory
	- in RAX: The start of the memory to dump
	- in RDX: Number of bytes to dump
#### DUMP_RAX		equ 0x81
	- Dump RAX register in Hex
	- in RAX: The Content that gets dump
#### DELAY			equ 0x82
#### RESET			equ 0x8D
#### REBOOT			equ 0x8E
#### SHUTDOWN		equ 0x8F


// EOF
