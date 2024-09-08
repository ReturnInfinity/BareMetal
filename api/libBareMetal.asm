; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; Version 1.0
; =============================================================================

; Kernel functions
b_input			equ 0x0000000000100010	; Scans keyboard for input. OUT: AL = 0 if no key pressed, otherwise ASCII code
b_output		equ 0x0000000000100018	; Displays a number of characters. IN: RSI = message location, RCX = number of characters

b_net_tx		equ 0x0000000000100020	; Transmit a packet via a network interface. IN: RSI = Memory location where packet is stored, RCX = Length of packet
b_net_rx		equ 0x0000000000100028	; Polls the network interface for received packet. IN: RDI = Memory location where packet will be stored. OUT: RCX = Length of packet

b_storage_read		equ 0x0000000000100030	; Read data from a drive. IN: RAX = Starting sector, RCX = Number of sectors to read, RDX = Drive, RDI = Memory location to store data
b_storage_write		equ 0x0000000000100038	; Write data to a drive. IN: RAX = Starting sector, RCX = Number of sectors to write, RDX = Drive, RSI = Memory location of data to store

b_system		equ 0x0000000000100040	; Configure system. IN: RCX = Function, RAX = Variable 1, RDX = Variable 2. OUT: RAX = Result


; Index for b_system calls
TIMECOUNTER		equ 0x00
FREE_MEMORY		equ 0x02
NETWORKCALLBACK_GET	equ 0x03
NETWORKCALLBACK_SET	equ 0x04
CLOCKCALLBACK_GET	equ 0x05
CLOCKCALLBACK_SET	equ 0x06
SMP_ID			equ 0x10
SMP_NUMCORES		equ 0x11
SMP_SET			equ 0x12
SMP_GET			equ 0x13
SMP_LOCK		equ 0x14
SMP_UNLOCK		equ 0x15
SMP_BUSY		equ 0x16
SCREEN_LFB_GET		equ 0x20
SCREEN_X_GET		equ 0x21
SCREEN_Y_GET		equ 0x22
SCREEN_PPSL_GET		equ 0x23
SCREEN_BPP_GET		equ 0x24
MAC_GET			equ 0x30
BUS_READ		equ 0x40
BUS_WRITE		equ 0x41
STDOUT_SET		equ 0x42
STDOUT_GET		equ 0x43
DUMP_MEM		equ 0x80
DUMP_RAX		equ 0x81
DELAY			equ 0x82
RESET			equ 0x8D
REBOOT			equ 0x8E
SHUTDOWN		equ 0x8F


; =============================================================================
; EOF
