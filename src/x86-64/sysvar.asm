; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2017 Return Infinity -- see LICENSE.TXT
;
; System Variables
; =============================================================================


; Constants
hextable: 		db '0123456789ABCDEF'

; Strings
system_status_header:	db 'BareMetal v1.0.0', 0
readymsg:		db 'BareMetal is ready'	; This string falls thru to newline
newline:		db 10, 0
memory_message:		db 'Not enough system memory for CPU stacks! System halted.', 0

; Memory addresses
sys_idt:		equ 0x0000000000000000	; 4096 bytes	0x000000 -> 0x000FFF	Interrupt descriptor table
sys_gdt:		equ 0x0000000000001000	; 4096 bytes	0x001000 -> 0x001FFF	Global descriptor table
sys_pml4:		equ 0x0000000000002000	; 4096 bytes	0x002000 -> 0x002FFF	PML4 table
sys_pdpl:		equ 0x0000000000003000	; 4096 bytes	0x003000 -> 0x003FFF	PDP table low
sys_pdph:		equ 0x0000000000004000	; 4096 bytes	0x004000 -> 0x004FFF	PDP table high
sys_Pure64:		equ 0x0000000000005000	; 12288 bytes	0x005000 -> 0x007FFF	Pure64 system data
sys_pdl:		equ 0x0000000000010000	; 65536 bytes	0x010000 -> 0x01FFFF	Page directory low
sys_pdh:		equ 0x0000000000020000	; 262144 bytes	0x020000 -> 0x05FFFF	Page directory high
ahci_cmdlist:		equ 0x0000000000070000	; 4096 bytes	0x070000 -> 0x071FFF
ahci_receivedfis:	equ 0x0000000000071000	; 4096 bytes	0x071000 -> 0x072FFF
ahci_cmdtable:		equ 0x0000000000072000	; 57344 bytes	0x072000 -> 0x07FFFF
os_temp_string:		equ 0x0000000000080400	; 1024 bytes	0x080400 -> 0x0807FF
os_args:		equ 0x0000000000080C00
sys_ROM:		equ 0x00000000000A0000	; 393216 bytes	0x0A0000 -> 0x0FFFFF
os_KernelStart:		equ 0x0000000000100000	; 65536 bytes	0x100000 -> 0x10FFFF	Location of Kernel
os_SystemVariables:	equ 0x0000000000110000	; 65536 bytes	0x110000 -> 0x11FFFF	Location of System Variables
os_MemoryMap:		equ 0x0000000000120000	; 131072 bytes	0x120000 -> 0x13FFFF	Location of Memory Map - Room to map 256 GiB with 2 MiB pages
os_EthernetBuffer:	equ 0x0000000000140000	; 262144 bytes	0x140000 -> 0x17FFFF	Location of Ethernet RX Ring Buffer - Room for 170 packets
os_temp:		equ 0x0000000000190000
os_rx_desc:		equ 0x00000000001A0000	; 32768 bytes	0x1A0000 -> 0x1A7FFF	Ethernet receive descriptors
os_tx_desc:		equ 0x00000000001A8000	; 32768 bytes	0x1A8000 -> 0x1AFFFF	Ethernet transmit descriptors
os_cpu_work_table:	equ 0x00000000001FF000	; Location of CPU Queue. Each queue item is 16 bytes. (4KiB before the 2MiB mark, Room for 256 entries)
programlocation:	equ 0x0000000000200000	; Location in memory where programs are loaded (the start of 2MiB)

; DQ - Starting at offset 0, increments by 8
os_LocalAPICAddress:	equ os_SystemVariables + 0
os_IOAPICAddress:	equ os_SystemVariables + 8
os_ClockCounter:	equ os_SystemVariables + 16
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
cpu_speed:		equ os_SystemVariables + 256	; in MHz
os_HPETRate:		equ os_SystemVariables + 260
os_MemAmount:		equ os_SystemVariables + 264	; in MiB
ahci_port:		equ os_SystemVariables + 268
hd1_size:		equ os_SystemVariables + 272	; in MiB

; DW - Starting at offset 512, increments by 2
os_NumCores:		equ os_SystemVariables + 512
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
app_argc:		equ os_SystemVariables + 785


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
