; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; System Variables
; =============================================================================


; Constants
screen_x:		equ 640
screen_y:		equ 480
screen_bpp:		equ 32


; Strings
system_status_header:	db 'BareMetal v1.0.0', 0
readymsg:		db 'BareMetal OK'	; This string falls through to newline
newline:		db 10, 0


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

; System memory
pci_table:		equ 0x0000000000120000	; 0x120000 -> 0x12FFFF	64K PCI Table
						; 0x130000 -> 0x13FFFF	64K Free
; Storage memory
ahci_basemem:		equ 0x0000000000140000	; 0x140000 -> 0x16FFFF	192K AHCI Structures
ahci_CLB:		equ 0x0000000000140000	; 0x140000 -> 0x147FFF	32K AHCI Command List Base (1K per port)
ahci_FB:		equ 0x0000000000148000	; 0x148000 -> 0x167FFF	128K AHCI FIS Base (4K per port)
ahci_CMD:		equ 0x0000000000168000	; 0x168000 -> 0x16FFFF	32K AHCI Commands
os_nvme:		equ 0x0000000000170000	; 0x170000 -> 0x17FFFF	64K NVMe Structures
os_nvme_asqb:		equ 0x0000000000170000	; 0x170000 -> 0x170FFF	4K Admin Submission Queue Base Address
os_nvme_acqb:		equ 0x0000000000171000	; 0x171000 -> 0x171FFF	4K Admin Completion Queue Base Address
os_nvme_iosqb:		equ 0x0000000000172000	; 0x172000 -> 0x172FFF	4K I/O Submission Queue Base Address
os_nvme_iocqb:		equ 0x0000000000173000	; 0x173000 -> 0x173FFF	4K I/O Completion Queue Base Address
os_nvme_CTRLID:		equ 0x0000000000174000	; 0x174000 -> 0x174FFF	4K Controller Identify Data
os_nvme_ANS:		equ 0x0000000000175000	; 0x175000 -> 0x175FFF	4K Namespace Data
os_nvme_NSID:		equ 0x0000000000176000	; 0x176000 -> 0x176FFF	4K Namespace Identify Data
os_nvme_rpr:		equ 0x0000000000177000	; 0x177000 -> 0x177FFF	4K RPR2 space for 1024 entries
						; 0x180000 -> 0x19FFFF	128K Free
; Network Memory
os_rx_desc:		equ 0x00000000001A0000	; 0x1A0000 -> 0x1A7FFF	32K Ethernet receive descriptors
os_tx_desc:		equ 0x00000000001A8000	; 0x1A8000 -> 0x1AFFFF	32K Ethernet transmit descriptors
os_PacketBuffers:	equ 0x00000000001B0000	;
os_SMP:			equ 0x00000000001FF800	; SMP table. Each item is 8 bytes. (2KiB before the 2MiB mark, Room for 256 entries)
app_start:		equ 0xFFFF800000000000	; Location of application memory


; DQ - Starting at offset 0, increments by 8
os_LocalAPICAddress:	equ os_SystemVariables + 0x0000
os_IOAPICAddress:	equ os_SystemVariables + 0x0008
os_ClockCounter:	equ os_SystemVariables + 0x0010
os_PacketAddress:	equ os_SystemVariables + 0x0018
os_StackBase:		equ os_SystemVariables + 0x0020
os_net_transmit:	equ os_SystemVariables + 0x0028
os_net_poll:		equ os_SystemVariables + 0x0030
os_net_ackint:		equ os_SystemVariables + 0x0038
os_NetIOBaseMem:	equ os_SystemVariables + 0x0040
os_NetMAC:		equ os_SystemVariables + 0x0048
os_HPETAddress:		equ os_SystemVariables + 0x0050
ahci_base:		equ os_SystemVariables + 0x0058
os_NetworkCallback:	equ os_SystemVariables + 0x0060
os_KeyboardCallback:	equ os_SystemVariables + 0x0068
os_ClockCallback:	equ os_SystemVariables + 0x0070
os_net_TXBytes:		equ os_SystemVariables + 0x0078
os_net_TXPackets:	equ os_SystemVariables + 0x0080
os_net_RXBytes:		equ os_SystemVariables + 0x0088
os_net_RXPackets:	equ os_SystemVariables + 0x0090
os_hdd_BytesRead:	equ os_SystemVariables + 0x0098
os_hdd_BytesWrite:	equ os_SystemVariables + 0x00A0
os_NVMe_Base:		equ os_SystemVariables + 0x00A8
os_storage_io:		equ os_SystemVariables + 0x00B0
os_storage_id:		equ os_SystemVariables + 0x00B8
os_screen_lfb:		equ os_SystemVariables + 0x00C0


; DD - Starting at offset 256, increments by 4
os_HPETRate:		equ os_SystemVariables + 0x0100
os_MemAmount:		equ os_SystemVariables + 0x0104	; in MiB
ahci_PA:		equ os_SystemVariables + 0x0108	; Each set bit is an active port
os_NVMeTotalLBA:	equ os_SystemVariables + 0x010C
os_apic_ver:		equ os_SystemVariables + 0x0110


; DW - Starting at offset 512, increments by 2
os_NumCores:		equ os_SystemVariables + 0x0200
os_CoreSpeed:		equ os_SystemVariables + 0x0202
os_NetIOAddress:	equ os_SystemVariables + 0x0204
os_NetLock:		equ os_SystemVariables + 0x0206
os_StorageVar:		equ os_SystemVariables + 0x0208
os_screen_x:		equ os_SystemVariables + 0x020A
os_screen_y:		equ os_SystemVariables + 0x020C
os_pcie_count:		equ os_SystemVariables + 0x020E


; DB - Starting at offset 768, increments by 1
scancode:		equ os_SystemVariables + 0x0300
key:			equ os_SystemVariables + 0x0301
key_shift:		equ os_SystemVariables + 0x0302
os_BusEnabled:		equ os_SystemVariables + 0x0303	; 1 if PCI is enabled, 2 if PCIe is enabled
os_NetEnabled:		equ os_SystemVariables + 0x0304	; 1 if a supported network card was enabled
os_NetIRQ:		equ os_SystemVariables + 0x0305	; Set to Interrupt line that NIC is connected to
os_NetActivity_TX:	equ os_SystemVariables + 0x0306
os_NetActivity_RX:	equ os_SystemVariables + 0x0307
os_EthernetBuffer_C1:	equ os_SystemVariables + 0x0308	; Counter 1 for the Ethernet RX Ring Buffer
os_EthernetBuffer_C2:	equ os_SystemVariables + 0x0309	; Counter 2 for the Ethernet RX Ring Buffer
os_StorageEnabled:	equ os_SystemVariables + 0x030A
os_StorageActivity:	equ os_SystemVariables + 0x030B
os_NVMeIRQ:		equ os_SystemVariables + 0x030C
os_NVMeMJR:		equ os_SystemVariables + 0x030D
os_NVMeMNR:		equ os_SystemVariables + 0x030E
os_NVMeTER:		equ os_SystemVariables + 0x030F
os_NVMeLBA:		equ os_SystemVariables + 0x0310
os_NVMe_atail:		equ os_SystemVariables + 0x0311
os_NVMe_iotail:		equ os_SystemVariables + 0x0312
os_AHCIMJR:		equ os_SystemVariables + 0x0313
os_AHCIMNR:		equ os_SystemVariables + 0x0314
os_AHCIIRQ:		equ os_SystemVariables + 0x0315
os_screen_bpp:		equ os_SystemVariables + 0x0316
os_ioapic_ver:		equ os_SystemVariables + 0x0317
os_ioapic_mde:		equ os_SystemVariables + 0x0318


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
