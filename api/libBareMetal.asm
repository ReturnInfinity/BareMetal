; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2023 Return Infinity -- see LICENSE.TXT
;
; Version 1.0
; =============================================================================


b_input			equ 0x0000000000100010	; Scans keyboard for input. OUT: AL = 0 if no key pressed, otherwise ASCII code
b_output		equ 0x0000000000100018	; Displays a number of characters. IN: RSI = message location, RCX = number of characters

b_net_tx		equ 0x0000000000100020	; Transmit a packet via a network interface. IN: RSI = Memory location where packet is stored, RCX = Length of packet
b_net_rx		equ 0x0000000000100028	; Polls the network interface for received packet. IN: RDI = Memory location where packet will be stored. OUT: RCX = Length of packet

b_storage_read		equ 0x0000000000100030	; Read data from a drive. IN: RAX = Starting sector, RCX = Number of sectors to read, RDX = Drive, RDI = Memory location to store data
b_storage_write		equ 0x0000000000100038	; Write data to a drive. IN: RAX = Starting sector, RCX = Number of sectors to write, RDX = Drive, RSI = Memory location of data to store

b_config		equ 0x0000000000100040	; View/modify configuration. IN: RCX = Function, RAX = Variable 1, RDX = Variable 2. OUT: RAX = Result
b_system		equ 0x0000000000100048	; Call a system function. IN: RCX = Function, RAX = Variable 1, RDX = Variable 2. Out: RAX = Result 1, RDX = Result 2


; Index for b_config calls
timecounter		equ 0x00
smp_get_id		equ 0x01
networkcallback_get	equ 0x03
networkcallback_set	equ 0x04
clockcallback_get	equ 0x05
clockcallback_set	equ 0x06
screen_lfb_get		equ 0x20
screen_x_get		equ 0x21
screen_y_get		equ 0x22
screen_bpp_get		equ 0x23
mac_get			equ 0x30
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
net_status		equ 7
mem_get_free		equ 8
smp_numcores		equ 9
smp_set			equ 10
reset			equ 256

; =============================================================================
; EOF
