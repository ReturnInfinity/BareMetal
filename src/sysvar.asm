; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; System Variables
; =============================================================================


; Strings
newline:		db 13, 10, 0
space:			db ' ', 0
system_status_header:	db 'BareMetal v1.0.0', 0

; Memory addresses

; x86-64 structures
sys_idt:		equ 0x0000000000000000	; 0x000000 -> 0x000FFF	4K Interrupt descriptor table
sys_gdt:		equ 0x0000000000001000	; 0x001000 -> 0x001FFF	4K Global descriptor table
sys_pml4:		equ 0x0000000000002000	; 0x002000 -> 0x002FFF	4K PML4 table
sys_pdpl:		equ 0x0000000000003000	; 0x003000 -> 0x003FFF	4K PDP table low
sys_pdph:		equ 0x0000000000004000	; 0x004000 -> 0x004FFF	4K PDP table high
sys_Pure64:		equ 0x0000000000005000	; 0x005000 -> 0x007FFF	12K Pure64 system data

						; 0x008000 -> 0x00FFFF	32K Free

sys_pdl:		equ 0x0000000000010000	; 0x010000 -> 0x01FFFF	64K Page directory low (Maps up to 16GB of 2MiB pages or 8TB of 1GiB pages)
sys_pdh:		equ 0x0000000000020000	; 0x020000 -> 0x09FFFF	512K Page directory high (Maps up to 128GB)

sys_ROM:		equ 0x00000000000A0000	; 0x0A0000 -> 0x0FFFFF	384K System ROM

; Kernel memory
os_KernelStart:		equ 0x0000000000100000	; 0x100000 -> 0x10FFFF	64K Kernel
os_SystemVariables:	equ 0x0000000000110000	; 0x110000 -> 0x11FFFF	64K System Variables

; System memory
bus_table:		equ 0x0000000000120000	; 0x120000 -> 0x12FFFF	64K Bus Table

; Non-volatile Storage memory
os_nvs_mem:		equ 0x0000000000130000	; 0x130000 -> 0x15FFFF	192K NVS structures/buffers

; USB memory
os_usb_mem:		equ 0x0000000000160000	; 0x160000 -> 0x19FFFF	256K USB structures/buffers

; Network memory
os_net_mem:		equ 0x00000000001A0000	; 0x1A0000 -> 0x1BFFFF	128K Network descriptors/buffers
os_rx_desc:		equ 0x00000000001A0000	; 0x1A0000 -> 0x1A7FFF	32K Ethernet receive descriptors
os_tx_desc:		equ 0x00000000001A8000	; 0x1A8000 -> 0x1AFFFF	32K Ethernet transmit descriptors
os_PacketBuffers:	equ 0x00000000001B0000	; 0x1B0000 -> 0x1BFFFF	64K Ethernet packet buffers

; LFB font data
os_font:		equ 0x00000000001C0000	; 0x1C0000 -> 0x1CFFFF	64K Font video data

						; 0x1D0000 -> 0x1DFFFF	64K Free

; Misc memory
os_SMP:			equ 0x00000000001FF800	; SMP table. Each item is 8 bytes. (2KiB before the 2MiB mark, Room for 256 entries)
app_start:		equ 0xFFFF800000000000	; Location of application memory


; DQ - Starting at offset 0, increments by 8
os_LocalAPICAddress:	equ os_SystemVariables + 0x0000
os_IOAPICAddress:	equ os_SystemVariables + 0x0008
os_SysConfEn:		equ os_SystemVariables + 0x0010	; Enabled bits: 0=PS/2 Keyboard, 1=PS/2 Mouse, 2=Serial, 4=HPET, 5=xHCI
os_PacketAddress:	equ os_SystemVariables + 0x0018
os_StackBase:		equ os_SystemVariables + 0x0020
os_net_transmit:	equ os_SystemVariables + 0x0028
os_net_poll:		equ os_SystemVariables + 0x0030
os_net_ackint:		equ os_SystemVariables + 0x0038
os_NetIOBaseMem:	equ os_SystemVariables + 0x0040
os_NetMAC:		equ os_SystemVariables + 0x0048
os_HPET_Address:	equ os_SystemVariables + 0x0050
os_AHCI_Base:		equ os_SystemVariables + 0x0058
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
os_nvs_io:		equ os_SystemVariables + 0x00B0
os_nvs_id:		equ os_SystemVariables + 0x00B8
os_screen_lfb:		equ os_SystemVariables + 0x00C0
os_virtioblk_base:	equ os_SystemVariables + 0x00C8
os_NetIOLength:		equ os_SystemVariables + 0x00D0
os_MouseCallback:	equ os_SystemVariables + 0x00D8
os_xHCI_Base:		equ os_SystemVariables + 0x00E0
os_usb_evtoken:		equ os_SystemVariables + 0x00E8


; DD - Starting at offset 256, increments by 4
os_HPETRate:		equ os_SystemVariables + 0x0100
os_MemAmount:		equ os_SystemVariables + 0x0104	; in MiB
os_AHCI_PA:		equ os_SystemVariables + 0x0108	; Each set bit is an active port
os_NVMeTotalLBA:	equ os_SystemVariables + 0x010C
os_apic_ver:		equ os_SystemVariables + 0x0110
os_HPET_Frequency:	equ os_SystemVariables + 0x0114
os_ps2_mouse_packet:	equ os_SystemVariables + 0x0118
os_xhci_int0_count:	equ os_SystemVariables + 0x011C	; Incremented on xHCI Interrupter 0


; DW - Starting at offset 512, increments by 2
os_NumCores:		equ os_SystemVariables + 0x0200
os_CoreSpeed:		equ os_SystemVariables + 0x0202
os_NetIOAddress:	equ os_SystemVariables + 0x0204
os_NetLock:		equ os_SystemVariables + 0x0206
os_nvsVar:		equ os_SystemVariables + 0x0208	; Bit 0 for NVMe, 1 for AHCI, 2 for ATA, 3 for Virtio Block
os_screen_x:		equ os_SystemVariables + 0x020A
os_screen_y:		equ os_SystemVariables + 0x020C
os_screen_ppsl:		equ os_SystemVariables + 0x020E
os_screen_bpp:		equ os_SystemVariables + 0x0210
os_pcie_count:		equ os_SystemVariables + 0x0212
os_HPET_CounterMin:	equ os_SystemVariables + 0x0214
os_ps2_mouse:		equ os_SystemVariables + 0x0218
os_ps2_mouse_buttons:	equ os_SystemVariables + 0x0218 ; Button state, bit 0 - left, bit 1 - right, bit 3 - middle. 0-released, 1-pressed
os_ps2_mouse_x:		equ os_SystemVariables + 0x021A ; Cursor screen position on X axis
os_ps2_mouse_y:		equ os_SystemVariables + 0x021C ; Cursor screen position on Y axis
os_ps2_mouse_count:	equ os_SystemVariables + 0x021E ; Byte counter
os_boot_arch:		equ os_SystemVariables + 0x0220 ; Bit 0 set for legacy ports, bit 1 set for 60/64 support


; DB - Starting at offset 768, increments by 1
scancode:		equ os_SystemVariables + 0x0300
key:			equ os_SystemVariables + 0x0301
key_shift:		equ os_SystemVariables + 0x0302
os_BusEnabled:		equ os_SystemVariables + 0x0303	; 1 if PCI is enabled, 2 if PCIe is enabled
os_NetEnabled:		equ os_SystemVariables + 0x0304	; 1 if a supported network card was enabled
os_NetIRQ:		equ os_SystemVariables + 0x0305	; Set to Interrupt line that NIC is connected to
;os_NetActivity_TX:	equ os_SystemVariables + 0x0306
;os_NetActivity_RX:	equ os_SystemVariables + 0x0307
;os_EthernetBuffer_C1:	equ os_SystemVariables + 0x0308	; Counter 1 for the Ethernet RX Ring Buffer
;os_EthernetBuffer_C2:	equ os_SystemVariables + 0x0309	; Counter 2 for the Ethernet RX Ring Buffer
;os_nvsEnabled:		equ os_SystemVariables + 0x030A
;os_nvsActivity:	equ os_SystemVariables + 0x030B
os_NVMeIRQ:		equ os_SystemVariables + 0x030C
os_NVMeMJR:		equ os_SystemVariables + 0x030D
os_NVMeMNR:		equ os_SystemVariables + 0x030E
os_NVMeTER:		equ os_SystemVariables + 0x030F
os_NVMeLBA:		equ os_SystemVariables + 0x0310
os_NVMe_atail:		equ os_SystemVariables + 0x0311
os_NVMe_iotail:		equ os_SystemVariables + 0x0312
os_AHCI_MJR:		equ os_SystemVariables + 0x0313
os_AHCI_MNR:		equ os_SystemVariables + 0x0314
os_AHCI_IRQ:		equ os_SystemVariables + 0x0315
os_ioapic_ver:		equ os_SystemVariables + 0x0316
os_ioapic_mde:		equ os_SystemVariables + 0x0317
key_control:		equ os_SystemVariables + 0x0318
os_BSP:			equ os_SystemVariables + 0x0319
os_HPET_IRQ:		equ os_SystemVariables + 0x031A


; Misc
tchar: db 0, 0


;------------------------------------------------------------------------------

SYS64_CODE_SEL	equ 8		; defined by Pure64

; =============================================================================
; EOF
