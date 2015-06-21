# BareMetal x86-64 API #

Version 1 - June 19, 2015

### Notes

This document details the API calls built into the BareMetal exokernel.

### Contents

1. Output
	- b\_output
	- b\_output\_chars
2. Input
	- b\_input
	- b\_input\_key
3. SMP
	- b\_smp\_enqueue
	- b\_smp\_dequeue
	- b\_smp\_run
	- b\_smp\_wait
4. Memory
	- b\_mem\_allocate
	- b\_mem\_release
5. Network
	- b\_net\_tx
	- b\_net\_rx
6. Disk
	- b\_disk\_read
	- b\_disk\_write
7. Misc
	- b\_system\_config
	- b\_system\_misc


## Output


### b\_output

Output text to the screen or via serial. The string must be null-terminated - also known as ASCIIZ.

Assembly Registers:

	 IN:	RSI = message location (zero-terminated string)
	OUT:	All registers preserved

Assembly Example:

	mov rsi, Message
	call b_output
	...
	Message: db 'This is a test', 0

C Example:

	char Message[] = "This is a test";
	b_output(Message);
	
	b_output("This is a another test");


### b\_output\_chars

Output a number of characters to the screen or via serial.

Assembly Registers:

	 IN:	RSI = message location
			RCX = number of characters to output
	OUT:	All registers preserved

Assembly Example:

	mov rsi, Message
	mov rcx, 4
	call os_output_chars					; Only output the word 'This'
	...
	Message: db 'This is a test', 0

C Example:

	b_output_chars("This is a test", 4);	// Output 'This'
	
	char Message[] = "Hello, world!";
	b_output_chars(Message, 5);				// Output 'Hello'


## Input


### b\_input

Accept a number of keys from the keyboard or via serial. The resulting string will automatically be null-terminated.

Assembly Registers:

	 IN:	RDI = location where string will be stored
			RCX = number of characters to accept
	OUT:	RCX = length of string that were input (NULL not counted)
			All other registers preserved

Assembly Example:

	mov rdi, Input
	mov rcx, 20
	call b_input
	...
	Input: db 0 times 21

C Example:

	char Input[21];
	b_input(Input, 20);


### b\_input\_key

Scans for input from keyboard or serial.

Assembly Registers:

	 IN:	Nothing
	OUT:	AL = 0 if no key pressed, otherwise ASCII code, other regs preserved
			All other registers preserved

Assembly Example:

	call b_input_key
	mov byte [KeyChar], al
	...
	KeyChar: db 0

C Example:

	char KeyChar;
	KeyChar = b_input_key();
	if (KeyChar == 'a')
	...


## SMP

BareMetal uses a queue for tasks. Tasks are automatically pulled out of the queue by available CPU cores.

### b\_smp\_enqueue

Add a workload to the processing queue.

Assembly Registers:

	 IN:	RAX = Address of code to execute
			RSI = Variable
	OUT:	Nothing

Assembly Example:

		mov rax, ap_code	; Our code to run on an available core
		xor rsi, rsi		; Clear RSI as there is no argument
		call [b_smp_enqueue]
		ret
		
	ap_code:
		...
		ret

C Example:

	

### b\_smp\_dequeue

Dequeue a workload from the processing queue.

Assembly Registers:

	 IN:	Nothing
	OUT:	RAX = Address of code to execute (Set to 0 if queue is empty)
			RDI = Variable

Assembly Example:


C Example:


### b\_smp\_run

Call the code address stored in RAX.

Assembly Registers:

	 IN:	RAX = Address of code to execute
	OUT:	Nothing

Assembly Example:


C Example:


### b\_smp\_wait

Wait until all other CPU Cores are finished processing.

Assembly Registers:

	 IN:	Nothing
	OUT:	Nothing. All registers preserved.

Assembly Example:


C Example:


## Memory

Memory is allocated in 2MiB pages.

### b\_mem\_allocate

Allocate pages of memory

Assembly Registers:

	 IN:	RCX = Number of pages to allocate
	OUT:	RAX = Starting address (Set to 0 on failure)
			All other registers preserved

Assembly Example:

	mov rcx, 2		; Allocate 2 2MiB pages (4MiB in total)
	call b_mem_allocate
	jz mem_fail
	mov rsi, rax	; Copy memory address to RSI


### b\_mem\_release

Release pages of memory

Assembly Registers:

	 IN:	RAX = Starting address
			RCX = Number of pages to free
	OUT:	RCX = Number of pages freed
			All other registers preserved

Assembly Example:

	mov rax, rsi	; Copy memory address to RAX
	mov rcx, 2		; Free 2 2MiB pages (4MiB in total)
	call b_mem_release


## Network


### b\_net\_tx

Transmit data via Ethernet

Assembly Registers:

	 IN:	RSI = memory location of packet
			RCX = length of packet
			RDX = Interface ID
	OUT:	All registers preserved

Assembly Example:

	mov rsi, Packet
	mov rcx, 1500
	mod rdx, 0
	call b_net_tx
	...
	Packet:
	Packet_Dest: db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF ; Broadcast
	Packet_Src: db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	Packet_Type: dw 0xABBA
	Packet_Data: db 'This is a test', 0

The packet must contain a proper 14-byte header.


### b\_net\_rx

Receive data via Ethernet

Assembly Registers:

	 IN:	RDI = memory location to store packet
			RDX = Interface ID
	OUT:	RCX = length of packet, 0 if nothing to receive

Assembly Example:

	mov rdi, Packet
	mov rdx, 0
	call b_net_rx
	...
	Packet: times 1518 db 0

Notes: BareMetal OS does not keep a buffer of received packets. This means that the OS will overwrite the last packet received as soon as it receives a new one. You can continuously poll the network by checking `b_net_rx` often, but this is not ideal. BareMetal OS allows for a network interrupt callback handler to be run whenever a packet is received. With a callback, your program will always be aware of when a packet was received. Check `programs/ethtool.asm` for an example of using a callback.


## Disk

BareMetal uses 4096 byte sectors for all disk access. Disk sectors start at 0. Individual calls to disk read and write functions support up to 512 sectors being read/written (2MiB).

### b\_disk\_read

Read a number of sectors from disk to memory

Assembly Registers:

	 IN:	RAX = Starting sector #
	 		RCX = Number of sectors to read
	 		RDX = Disk #
			RDI = Destination memory address
	OUT:	RCX = Number of sectors read
			All other registers preserved

Assembly Example:

	mov rax, 0		; Read sector 0
	mov rcx, 1		; Read one sector
	mov rdx, 0		; Read from Disk 0
	mov rdi, diskbuffer	; Read disk to this memory address
	call b_disk_read


### b\_disk\_write

Write a number of sectors from memory to disk

Assembly Registers:

	 IN:	RAX = Starting sector #
	 		RCX = Number of sectors to write
	 		RDX = Disk #
			RSI = Source memory address
	OUT:	RCX = Number of sectors written
			All other registers preserved

Assembly Example:

	mov rax, 0		; Write to sector 0
	mov rcx, 1		; Write one sector
	mov rdx, 0		; Write to Disk 0
	mov rsi, diskbuffer	; Write the contents from this memory address to disk
	call b_disk_write


## Misc


### b\_system\_config

View or modify system configuration options

Assembly Registers:

	 IN:	RDX = Function #
			RAX = Variable 1
	OUT:	RAX = Result 1

Function numbers come in pairs (one for reading a parameter, and one for writing a parameter). `b_system_config` should be called with a function alias and not a direct function number.


### b\_system\_misc

Call miscellaneous OS sub-functions

Assembly Registers:

	 IN:	RDX = Function #
			RAX = Variable 1
			RCX = Variable 2 
	OUT:	RAX = Result 1
			RCX = Result 2

