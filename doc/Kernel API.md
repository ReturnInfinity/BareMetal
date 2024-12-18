# BareMetal x86-64 API

Version 1.1 - September 8, 2024


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

	b_output("This is a test", 4);	// Output 'This'

	char Message[] = "Hello, world!";
	b_output(Message, 5);				// Output 'Hello'


## Network


### b\_net\_tx

Transmit data via a network interface.

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

Receive data via a network interface.

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

Read a number of sectors from a drive to memory.

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

Write a number of sectors from memory to a drive.

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

#### TIMECOUNTER

Read the HPET Main Timer.

	 IN:	Nothing
	OUT:	RAX = Number of HPET ticks since kernel start
		All other registers preserved

#### FREE_MEMORY

Return the amount of free memory.

	 IN:	Nothing
	OUT:	RAX = Free memory in Mebibytes (MiB)
		All other registers preserved

#### MOUSE

Return details of the mouse

	 IN:	Nothing
	OUT:	RAX = Mouse details
		All other registers preserved
		Bits 63:48 - Padding
		Bits 47:32 - Y position
		Bits 31:16 - X position
		Bits 15:0  - Buttons pressed

#### SMP_ID

Returns the APIC ID of the CPU that ran this function.

	 IN:	Nothing
	OUT:	RAX = CPU's APIC ID number
		All other registers preserved

#### SMP_NUMCORES

Returns the total number of CPU cores.

	 IN:	Nothing
	OUT:	RAX = Number of CPU cores
		All other registers preserved

#### SMP_SET

Set a specific CPU to run code.

	 IN:	RAX = Code address
		RDX = CPU APIC ID
	OUT:	RAX = 0 on error
	Note:	Code address must be 16-byte aligned

#### SMP_GET

Returns a CPU code address and flags.

	 IN:	Nothing
	OUT:	RAX = Code address (bits 63:4) and flags (bits 3:0)

#### SMP_LOCK

Attempt to lock a mutex.

	 IN:	RAX = Address of lock variable
	OUT:	Nothing. All registers preserved

#### SMP_UNLOCK

Unlock a mutex.

	 IN:	RAX = Address of lock variable
	OUT:	Nothing. All registers preserved

#### SMP_BUSY

Check if CPU cores are busy.

	 IN:	Nothing
	OUT:	RAX = 1 if CPU cores are busy, 0 if not
		All other registers preserved
	Note:	This ignores the core it is running on

#### SCREEN_LFB_GET

Return the address of the linear frame buffer.

	 IN:	Nothing
	OUT:	RAX = Address of linear frame buffer
		All other registers preserved

#### SCREEN_X_GET

Return the amount of pixels along the horizontal.

	 IN:	Nothing
	OUT:	RAX = Number of pixels
		All other registers preserved

#### SCREEN_Y_GET

Return the amount of pixels along the vertical.

	 IN:	Nothing
	OUT:	RAX = Number of pixels
		All other registers preserved

#### SCREEN_PPSL_GET

Return the number of pixels per scan line. This may be more than `SCREEN_X` due to memory alignment requirements.

	 IN:	Nothing
	OUT:	RAX = Number of pixels per scan line
		All other registers preserved

#### SCREEN_BPP_GET

Return the number of bits per pixel. This should return 32.

	 IN:	Nothing
	OUT:	RAX = Bits per pixel
		All other registers preserved

#### MAC_GET

Return the MAC address of the network device.

	 IN:	Nothing
	OUT:	RAX = MAC address (bits 0-47)
		All other registers preserved

#### BUS_READ

#### BUS_WRITE

#### STDOUT_SET

#### STDOUT_GET

#### CALLBACK_TIMER

#### CALLBACK_NETWORK

#### CALLBACK_KEYBOARD

#### CALLBACK_MOUSE

Set a callback for execution on mouse activity.

	 IN:	Nothing
	OUT:	RAX = Address of callback
		All other registers preserved

Set a callback of 0x0 to disable it.

#### DUMP_MEM

Dump contents of memory

	 IN:	RAX: The start of the memory to dump
		RDX: Number of bytes to dump
	OUT:	All registers preserved

#### DUMP_RAX

Dump RAX register in Hex

	 IN:	RAX: The content that gets dump
	OUT:	All registers preserved

#### DELAY

Delay by X microseconds

	 IN:	RAX = Time microseconds
	OUT:	All registers preserved

#### RESET

Reset all other CPU cores

	 IN:	Nothing
	OUT:	All registers preserved (on the caller CPU)

#### REBOOT

Reboot the system

	 IN:	Nothing
	OUT:	All registers lost

#### SHUTDOWN

Shut down the system

	 IN:	Nothing
	OUT:	All registers lost


// EOF
