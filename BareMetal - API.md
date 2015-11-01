# BareMetal x86-64 API #

Version 1 - June 19, 2015

### Notes

This document details the API calls built into the BareMetal exokernel.

### Contents

1. Output
	- os\_output
	- os\_output\_chars
2. Input
	- os\_input
	- os\_input\_key
3. SMP
	- os\_smp\_enqueue
	- os\_smp\_dequeue
	- os\_smp\_run
	- os\_smp\_wait
4. Memory
	- os\_mem\_allocate
	- os\_mem\_release
5. Network
	- os\_net\_tx
	- os\_net\_rx
6. Disk
	- os\_disk\_read
	- os\_disk\_write
7. Misc
	- os\_system\_config
	- os\_system\_misc


## Output


### os\_output

Output text to the screen or via serial. The string must be null-terminated (also known as ASCIIZ).

Assembly Registers:

	 IN:	RSI = message location (zero-terminated string)
	OUT:	All registers preserved

Assembly Example:

	mov rsi, Message
	call os_output
	...
	Message: db 'This is a test', 0

### os\_output\_chars

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

## Input


### os\_input

Accept a number of keys from the keyboard or via serial. The resulting string will automatically be null-terminated.

Assembly Registers:

	 IN:	RDI = location where string will be stored
			RCX = number of characters to accept
	OUT:	RCX = length of string that were input (NULL not counted)
			All other registers preserved

Assembly Example:

	mov rdi, Input
	mov rcx, 20
	call os_input
	...
	Input: db 0 times 21


### os\_input\_key

Scans for input from keyboard or serial.

Assembly Registers:

	 IN:	Nothing
	OUT:	AL = 0 if no key pressed, otherwise ASCII code, other regs preserved
			All other registers preserved

Assembly Example:

	call os_input_key
	mov byte [KeyChar], al
	...
	KeyChar: db 0


## SMP

BareMetal uses a queue for tasks. Available CPU cores poll the queue for tasks and pull them out automatically.

### os\_smp\_enqueue

Add a workload to the processing queue.

Assembly Registers:

	 IN:	RAX = Address of code to execute
			RSI = Variable
	OUT:	Nothing

Assembly Example:

		mov rax, ap_code	; Our code to run on an available core
		xor rsi, rsi		; Clear RSI as there is no argument
		call [os_smp_enqueue]
		ret
		
	ap_code:
		...
		ret


### os\_smp\_dequeue

Dequeue a workload from the processing queue.

Assembly Registers:

	 IN:	Nothing
	OUT:	RAX = Address of code to execute (Set to 0 if queue is empty)
			RDI = Variable

Assembly Example:


### os\_smp\_run

Call the code address stored in RAX.

Assembly Registers:

	 IN:	RAX = Address of code to execute
	OUT:	Nothing

Assembly Example:


### os\_smp\_wait

Wait until all other CPU Cores are finished processing.

Assembly Registers:

	 IN:	Nothing
	OUT:	Nothing. All registers preserved.

Assembly Example:


## Memory

Memory in BareMetal is allocated in 2MiB pages.

### os\_mem\_allocate

Allocate a number of 2MiB pages of memory

Assembly Registers:

	 IN:	RCX = Number of pages to allocate
	OUT:	RAX = Starting address (Set to 0 on failure)
			All other registers preserved

Assembly Example:

	mov rcx, 2		; Allocate 2 2MiB pages (4MiB in total)
	call os_mem_allocate
	jz mem_fail		; Memory allocation failed
	mov rsi, rax		; Copy memory address to RSI


### os\_mem\_release

Release pages of memory

Assembly Registers:

	 IN:	RAX = Starting address
			RCX = Number of pages to free
	OUT:	RCX = Number of pages freed
			All other registers preserved

Assembly Example:

	mov rax, rsi	; Copy memory address to RAX
	mov rcx, 2		; Free 2 2MiB pages (4MiB in total)
	call os_mem_release


## Network


### os\_net\_tx

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
	call os_net_tx
	...
	Packet:
	Packet_Dest: db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF ; Broadcast
	Packet_Src: db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	Packet_Type: dw 0xABBA
	Packet_Data: db 'This is a test', 0

Please note that the packet must contain a proper 14-byte header.


### os\_net\_rx

Receive data via Ethernet

Assembly Registers:

	 IN:	RDI = memory location to store packet
			RDX = Interface ID
	OUT:	RCX = length of packet, 0 if nothing to receive

Assembly Example:

	mov rdi, Packet
	mov rdx, 0
	call os_net_rx
	...
	Packet: times 1518 db 0

Note: BareMetal does not keep a buffer of received packets. This means that the OS will overwrite the last packet as soon as a new one is received. Continuously polling the network by checking `os_net_rx` often, is possible, but this is not ideal. BareMetal allows for a network interrupt callback handler to be run whenever a packet is received. With a callback, a program will always be aware of when a packet is received. Check [`programs/ethtool.asm`](https://github.com/ReturnInfinity/BareMetal-OS/blob/master/programs/ethtool.asm) for an example of using a callback.


## Disk

BareMetal uses 4096 byte sectors for all disk access. Disk sectors start at 0. Individual calls to disk read and write functions support up to 512 sectors being read/written (2MiB).

### os\_disk\_read

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
	call os_disk_read


### os\_disk\_write

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
	call os_disk_write

## Misc

### os\_system\_config

View or modify system configuration options

Assembly Registers:

	 IN:	RDX = Function #
			RAX = Variable 1
	OUT:	RAX = Result 1

Function numbers come in pairs (one for reading a parameter, and one for writing a parameter). `os_system_config` should be called with a function alias and not a direct function number.

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

### os\_system\_misc

Call miscellaneous OS sub-functions

Assembly Registers:

	 IN:	RDX = Function #
			RAX = Variable 1
			RCX = Variable 2 
	OUT:	RAX = Result 1
			RCX = Result 2

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
	- in rcx: Number of bytes to dump
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
	- out rcx: Number of pages
9. smp_numcores
	- Returns the number of cores in this computer
	- out rcx: The number of cores
10. smp_queuelen
	- Returns the number of items in the processing queue
	- out rax: Number of items in processing queue
