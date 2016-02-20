; =============================================================================
; Pure64 -- a 64-bit OS loader written in Assembly for x86-64 systems
; Copyright (C) 2008-2016 Return Infinity -- see LICENSE.TXT
;
; PCI Functions. http://wiki.osdev.org/PCI
; =============================================================================


; -----------------------------------------------------------------------------
; os_pci_read_reg -- Read a register from a PCI device
;  IN:	BL  = Bus number
;	CL  = Device/Function number
;	DL  = Register number
; OUT:	EAX = Register information
;	All other registers preserved
; Data form is binary 10000000 bbbbbbbb dddddfff rrrrrr00
os_pci_read_reg:
	push rdx
	push rcx
	push rbx

	shl ebx, 16			; Move Bus to bits 23 - 16
	shl ecx, 8			; Move Device/Function to bits 15 - 8
	or ebx, ecx
	shl edx, 2			; Move Register to bits 7 - 2
	or ebx, edx
	and ebx, 0x00ffffff		; Clear bits 31 - 24
	or ebx, 0x80000000		; Set bit 31
	mov eax, ebx
	mov dx, PCI_CONFIG_ADDRESS
	out dx, eax
	mov dx, PCI_CONFIG_DATA
	in eax, dx

	pop rbx
	pop rcx
	pop rdx
ret
; -----------------------------------------------------------------------------

;Configuration Mechanism One has two IO port rages associated with it.
;The address port (0xcf8-0xcfb) and the data port (0xcfc-0xcff).
;A configuration cycle consists of writing to the address port to specify which device and register you want to access and then reading or writing the data to the data port.

PCI_CONFIG_ADDRESS	EQU	0x0CF8
PCI_CONFIG_DATA		EQU	0x0CFC

;ddress dd 10000000000000000000000000000000b
;          /\     /\      /\   /\ /\    /\
;        E    Res    Bus    Dev  F  Reg   0
; Bits
; 31		Enable bit = set to 1
; 30 - 24	Reserved = set to 0
; 23 - 16	Bus number = 256 options
; 15 - 11	Device/Slot number = 32 options
; 10 - 8	Function number = will leave at 0 (8 options)
; 7 - 2		Register number = will leave at 0 (64 options) 64 x 4 bytes = 256 bytes worth of accessible registers
; 1 - 0		Set to 0


; =============================================================================
; EOF
