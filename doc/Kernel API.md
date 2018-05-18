# BareMetal x86-64 API

Version 1 - November 12, 2017


### Notes

This document details the API calls built into the BareMetal exokernel.


### Contents

1. Input/Output
	- b\_input
	- b\_output
2. SMP
	- b\_smp\_set
	- b\_smp\_config
3. Memory
	- b\_mem\_allocate
	- b\_mem\_release
4. Network
	- b\_net\_tx
	- b\_net\_rx
5. Disk
	- b\_disk\_read
	- b\_disk\_write
6. Misc
	- b\_system\_config
	- b\_system\_misc


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


## SMP


### b\_smp\_set


Set a CPU to a specific task.

Assembly Registers:

	 IN:	RAX = Code address
		RDX = Data address
		RCX = CPU APIC ID
	OUT:	RAX = 0 on error

Assembly Example:

		mov rax, ap_code	; Our code to run on an available core
		xor rdx, rdx		; Clear RDX as there is no argument
		mov rcx, 1		; Set CPU with ID 1 to run code
		call [b_smp_set]
		ret

	ap_code:
		...
		ret

C Example:



### b\_smp\_config

Just a stub fuction at the moment


## Memory

Memory is allocated in 2MiB pages.


### b\_mem\_allocate

Allocate pages of memory

Assembly Registers:

	 IN:	RCX = Number of pages to allocate
	OUT:	RAX = Starting address (Set to 0 on failure)
		All other registers preserved

Assembly Example:

	mov rcx, 2			; Allocate 2 2MiB pages (4MiB in total)
	call [b_mem_allocate]
	jz mem_fail
	mov rsi, rax			; Copy memory address to RSI


### b\_mem\_release

Release pages of memory

Assembly Registers:

	 IN:	RAX = Starting address
		RCX = Number of pages to free
	OUT:	RCX = Number of pages freed
		All other registers preserved

Assembly Example:

	mov rax, rsi			; Copy memory address to RAX
	mov rcx, 2			; Free 2 2MiB pages (4MiB in total)
	call [b_mem_release]


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
	call [b_net_tx]
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
	call [b_net_rx]
	...
	Packet: times 1518 db 0

Note: BareMetal does not keep a buffer of received packets. This means that the OS will overwrite the last packet as soon as a new one is received. Continuously polling the network by checking `os_net_rx` often, is possible, but this is not ideal. BareMetal allows for a network interrupt callback handler to be run whenever a packet is received. With a callback, a program will always be aware of when a packet is received.


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

	mov rax, 0			; Read sector 0
	mov rcx, 1			; Read one sector
	mov rdx, 0			; Read from Disk 0
	mov rdi, diskbuffer		; Read disk to this memory address
	call [b_disk_read]


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

	mov rax, 0			; Write to sector 0
	mov rcx, 1			; Write one sector
	mov rdx, 0			; Write to Disk 0
	mov rsi, diskbuffer		; Write the contents from this memory address to disk
	call [b_disk_write]


## Misc


### b\_system\_config

View or modify system configuration options

Assembly Registers:

	 IN:	RCX = Function
		RAX = Variable 1
		RDX = Variable 2
	OUT:	RAX = Result

Function numbers come in pairs (one for reading a parameter, and one for writing a parameter). `b_system_config` should be called with a function alias and not a direct function number.

Currently the following functions are supported:

 - 0: timecounter

   get the timecounter, the timecounter increments 8 times a second
 - 1: argc

   get the argument count
 - 2: argv

   get the nth argument
 - 3: networkcallback_get

   get the current networkcallback entrypoint
 - 4: networkcallback_set

   set the current networkcallback entrypoint
 - 5: clockcallback_get

   get the current clockcallback entrypoint
 - 6: clockcallback_set

   set the current clockcallback entrypoint
 - 30: mac

   get the current mac address (or 0 if ethernet is down)

every function that gets something sets RAX with the result

every function that sets something gets the value from RAX


### b\_system\_misc

Call miscellaneous OS sub-functions

Assembly Registers:

	 IN:	RCX = Function
		RAX = Variable 1
		RDX = Variable 2
	OUT:	RAX = Result 1
		RDX = Result 2

Currently the following functions are supported:

1. smp_get_id
	- Returns the APIC ID of the CPU that ran this function
	- out rax: The ID
2. smp_lock
	- Attempt to lock a mutex, this is a simple spinlock
	- in rax: The address of the mutex (one word)
3. smp_unlock
	- Unlock a mutex
	- in rax: The address of the mutex (one word)
4. debug_dump_mem
	- os_debug_dump_mem
	- in rax: The start of the memory to dump
	- in rdx: Number of bytes to dump
5. debug_dump_rax
	- Dump rax in Hex
	- in rax: The Content that gets printed to memory
6. delay
	- Delay by X eights of a second
	- in rax: Time in eights of a second
7. ethernet_status
	- Get the current mac address (or 0 if ethernet is down)
	- Same as system_config 30 (mac)
	- out rax: The mac address
8. mem_get_free
	- Returns the number of 2 MiB pages that are available
	- out rax: Number of pages
9. smp_numcores
	- Returns the number of cores in this computer
	- out rax: The number of cores
10. smp_queuelen
	- Returns the number of items in the processing queue
	- out rax: Number of items in processing queue


// EOF
