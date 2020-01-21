; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2020 Return Infinity -- see LICENSE.TXT
;
; Version 1.0
; =============================================================================


b_input			equ 0x0000000000100010	; Scans keyboard for input. OUT: AL = 0 if no key pressed, otherwise ASCII code
b_output		equ 0x0000000000100018	; Displays a number of characters. IN: RSI = message location, RCX = number of characters

b_ethernet_tx		equ 0x0000000000100020	; Transmit a packet via Ethernet. IN: RSI = Memory location where data is stored, RDI = Pointer to 48 bit destination address, BX = Type of packet (If set to 0 then the EtherType will be set to the length of data), CX = Length of data
b_ethernet_rx		equ 0x0000000000100028	; Polls the Ethernet card for received data. IN: RDI = Memory location where packet will be stored. OUT: RCX = Length of packet

b_disk_read		equ 0x0000000000100030	; Read from the disk.
b_disk_write		equ 0x0000000000100038	; Write to the disk.

b_config		equ 0x0000000000100040	; View/modify configuration. IN: RCX = Function, RAX = Variable 1, RDX = Variable 2. OUT: RAX = Result
b_system		equ 0x0000000000100048	; Call a system function. IN: RCX = Function, RAX = Variable 1, RDX = Variable 2. Out: RAX = Result 1, RDX = Result 2


; Index for b_config calls
timecounter		equ 0
smp_get_id		equ 1
networkcallback_get	equ 3
networkcallback_set	equ 4
clockcallback_get	equ 5
clockcallback_set	equ 6
mac			equ 30
pci_read		equ 0x40
pci_write		equ 0x41
stdout_set		equ 0x42
stdout_get		equ 0x43
drive_id		equ 0x50


; Index for b_system calls
smp_lock		equ 2
smp_unlock		equ 3
debug_dump_mem		equ 4
debug_dump_rax		equ 5
get_argc		equ 6
get_argv		equ 7
delay			equ 6
ethernet_status		equ 7
mem_get_free		equ 8
smp_numcores		equ 9
smp_set			equ 10
reset			equ 256

; =============================================================================
; EOF
