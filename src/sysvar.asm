; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2020 Return Infinity -- see LICENSE.TXT
;
; System Variables
; =============================================================================


; Constants
hextable: 		db '0123456789ABCDEF'


; Strings
system_status_header:	db 'BareMetal v1.0.0', 0
readymsg:		db 'BareMetal OK'	; This string falls thru to newline
newline:		db 10, 0
memory_message:		db 'Not enough system memory for CPU stacks! System halted.', 0


; Memory addresses
sys_idt:		equ 0x0000000000000000	; 0x000000 -> 0x000FFF	4K Interrupt descriptor table
sys_gdt:		equ 0x0000000000001000	; 0x001000 -> 0x001FFF	4K Global descriptor table
sys_pml4:		equ 0x0000000000002000	; 0x002000 -> 0x002FFF	4K PML4 table
sys_pdpl:		equ 0x0000000000003000	; 0x003000 -> 0x003FFF	4K PDP table low
sys_pdph:		equ 0x0000000000004000	; 0x004000 -> 0x004FFF	4K PDP table high
sys_Pure64:		equ 0x0000000000005000	; 0x005000 -> 0x007FFF	12K Pure64 system data
						; 0x008000 -> 0x00FFFF	32K Free
sys_pdl:		equ 0x0000000000010000	; 0x010000 -> 0x01FFFF	64K Page directory low (Maps up to 16GB)
sys_pdh:		equ 0x0000000000020000	; 0x020000 -> 0x05FFFF	256K Page directory high (Maps up to 64GB)
						; 0x060000 -> 0x09FFFF	256K Free
sys_ROM:		equ 0x00000000000A0000	; 0x0A0000 -> 0x0FFFFF	384K System ROM
os_KernelStart:		equ 0x0000000000100000	; 0x100000 -> 0x10FFFF	64K Kernel
os_SystemVariables:	equ 0x0000000000110000	; 0x110000 -> 0x11FFFF	64K System Variables
						; 0x120000 -> 0x19FFFF	512K Free
ahci_CLB:		equ 0x0000000000140000	; 0x140000 -> 0x147FFF	32K AHCI Command List Base (1K per port)
ahci_FB:		equ 0x0000000000148000	; 0x148000 -> 0x167FFF	128K AHCI FIS Base (4K per port)
ahci_CMD:		equ 0x0000000000168000	; 0x168000 -> 0x16FFFF	32K AHCI Commands
						; 0x170000 -> 0x19FFFF	192K Free
os_rx_desc:		equ 0x00000000001A0000	; 0x1A0000 -> 0x1A7FFF	32K Ethernet receive descriptors
os_tx_desc:		equ 0x00000000001A8000	; 0x1A8000 -> 0x1AFFFF	32K Ethernet transmit descriptors
os_PacketBuffers:	equ 0x00000000001B0000	;
os_SMP:			equ 0x00000000001FF800	; SMP table. Each item is 8 bytes. (2KiB before the 2MiB mark, Room for 256 entries)
app_start:		equ 0xFFFF800000000000	; Location of application memory

; DQ - Starting at offset 0, increments by 8
os_LocalAPICAddress:	equ os_SystemVariables + 0
os_IOAPICAddress:	equ os_SystemVariables + 8
os_ClockCounter:	equ os_SystemVariables + 16
os_PacketAddress:	equ os_SystemVariables + 24
os_StackBase:		equ os_SystemVariables + 40
os_net_transmit:	equ os_SystemVariables + 48
os_net_poll:		equ os_SystemVariables + 56
os_net_ackint:		equ os_SystemVariables + 64
os_NetIOBaseMem:	equ os_SystemVariables + 72
os_NetMAC:		equ os_SystemVariables + 80
os_HPETAddress:		equ os_SystemVariables + 88
ahci_base:		equ os_SystemVariables + 96
os_NetworkCallback:	equ os_SystemVariables + 104
os_KeyboardCallback:	equ os_SystemVariables + 120
os_ClockCallback:	equ os_SystemVariables + 128
os_net_TXBytes:		equ os_SystemVariables + 136
os_net_TXPackets:	equ os_SystemVariables + 144
os_net_RXBytes:		equ os_SystemVariables + 152
os_net_RXPackets:	equ os_SystemVariables + 160
os_hdd_BytesRead:	equ os_SystemVariables + 168
os_hdd_BytesWrite:	equ os_SystemVariables + 176


; DD - Starting at offset 256, increments by 4
os_HPETRate:		equ os_SystemVariables + 260
os_MemAmount:		equ os_SystemVariables + 264	; in MiB
ahci_PA:		equ os_SystemVariables + 268	; Each set bit is an active port


; DW - Starting at offset 512, increments by 2
os_NumCores:		equ os_SystemVariables + 512
os_CoreSpeed:		equ os_SystemVariables + 514
os_NetIOAddress:	equ os_SystemVariables + 522
os_NetLock:		equ os_SystemVariables + 524


; DB - Starting at offset 768, increments by 1
scancode:		equ os_SystemVariables + 770
key:			equ os_SystemVariables + 771
key_shift:		equ os_SystemVariables + 772
os_PCIEnabled:		equ os_SystemVariables + 775	; 1 if PCI is detected
os_NetEnabled:		equ os_SystemVariables + 776	; 1 if a supported network card was enabled
os_NetIRQ:		equ os_SystemVariables + 778	; Set to Interrupt line that NIC is connected to
os_NetActivity_TX:	equ os_SystemVariables + 779
os_NetActivity_RX:	equ os_SystemVariables + 780
os_EthernetBuffer_C1:	equ os_SystemVariables + 781	; Counter 1 for the Ethernet RX Ring Buffer
os_EthernetBuffer_C2:	equ os_SystemVariables + 782	; Counter 2 for the Ethernet RX Ring Buffer
os_DiskEnabled:		equ os_SystemVariables + 783
os_DiskActivity:	equ os_SystemVariables + 784


; Misc
keylayoutlower:
db 0x00, 0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0x0e, 0, 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0x1c, 0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', 0x27, '`', 0, '\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, 0, 0, ' ', 0
keylayoutupper:
db 0x00, 0, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 0x0e, 0, 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', 0x1c, 0, 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', 0x22, '~', 0, '|', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, 0, 0, ' ', 0
; 0e = backspace
; 1c = enter
tchar: db 0, 0


;------------------------------------------------------------------------------

SYS64_CODE_SEL	equ 8		; defined by Pure64

; =============================================================================
; EOF
