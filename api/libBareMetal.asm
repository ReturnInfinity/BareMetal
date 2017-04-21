; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2017 Return Infinity -- see LICENSE.TXT
;
; Version 1.0
; =============================================================================


b_output		equ 0x0000000000100010	; Displays text. IN: RSI = message location (zero-terminated string)
b_output_chars		equ 0x0000000000100018	; Displays a number of characters. IN: RSI = message location, RCX = number of characters

b_input			equ 0x0000000000100020	; Take string from keyboard entry. IN: RDI = location where string will be stored. RCX = max chars to accept
b_input_key		equ 0x0000000000100028	; Scans keyboard for input. OUT: AL = 0 if no key pressed, otherwise ASCII code

b_smp_set		equ 0x0000000000100030	; Set a CPU to run code. IN: RAX = Code address, RDX = Data address, RCX = CPU ID
b_smp_config		equ 0x0000000000100038	; Stub

b_mem_allocate		equ 0x0000000000100040	; Allocates the requested number of 2 MiB pages. IN: RCX = Number of pages to allocate. OUT: RAX = Starting address, RCX = Number of pages allocated (Set to the value asked for or 0 on failure)
b_mem_release		equ 0x0000000000100048	; Frees the requested number of 2 MiB pages. IN: RAX = Starting address, RCX = Number of pages to free. OUT: RCX = Number of pages freed

b_ethernet_tx		equ 0x0000000000100050	; Transmit a packet via Ethernet. IN: RSI = Memory location where data is stored, RDI = Pointer to 48 bit destination address, BX = Type of packet (If set to 0 then the EtherType will be set to the length of data), CX = Length of data
b_ethernet_rx		equ 0x0000000000100058	; Polls the Ethernet card for received data. IN: RDI = Memory location where packet will be stored. OUT: RCX = Length of packet

b_disk_read		equ 0x0000000000100060	; Read from the disk.
b_disk_write		equ 0x0000000000100068	; Write to the disk.

b_system_config		equ 0x0000000000100070	; View/modify system configuration. IN: RDX = Function #, RAX = Variable. OUT: RAX = Result
b_system_misc		equ 0x0000000000100078	; Call a misc system function. IN: RDX = Function #, RAX = Variable 1, RCX = Variable 2. Out: RAX = Result 1, RCX = Result 2


; Index for b_system_config calls
timecounter		equ 0
config_argc		equ 1
config_argv		equ 2
networkcallback_get	equ 3
networkcallback_set	equ 4
clockcallback_get	equ 5
clockcallback_set	equ 6


; Index for b_system_misc calls
smp_get_id		equ 1
smp_lock		equ 2
smp_unlock		equ 3
debug_dump_mem		equ 4
debug_dump_rax		equ 5
get_argc		equ 6
get_argv		equ 7


; =============================================================================
; EOF
