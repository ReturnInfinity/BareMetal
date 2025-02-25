; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; PCI Functions
; =============================================================================


; See syscalls/bus.asm for description on RDX format


; -----------------------------------------------------------------------------
; os_pci_read -- Read from a register on a PCI device
;  IN:	RDX = Register to read from
; OUT:	EAX = Register value that was read
;	All other registers preserved
os_pci_read:
	push rdx

	call os_pci_convert		; Convert RDX to a PCI Address

	mov dx, PCI_CONFIG_ADDRESS
	out dx, eax
	mov dx, PCI_CONFIG_DATA
	in eax, dx

	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_pci_write -- Write to a register on a PCI device
;  IN:	RDX = Register to write to
;	EAX = Register value to be written
; OUT:	Nothing, all registers preserved
os_pci_write:
	push rdx
	push rax			; Save the value to be written

	call os_pci_convert		; Convert RDX to a PCI Address

	mov dx, PCI_CONFIG_ADDRESS
	out dx, eax
	pop rax				; Restore the value and write it
	mov dx, PCI_CONFIG_DATA
	out dx, eax

	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_pci_convert -- Convert the value in EDX to what is expected for PCI access
;  IN:	EDX = Register
;	EAX = PCI Address
; OUT:	Nothing, all registers preserved
os_pci_convert:
	mov eax, edx			; Save EDX for the register value later on
	shl al, 2			; Shift PCI register ID left two bits
	shr edx, 8			; Shift Bus/Device/Function
	mov dl, al			; Restore register value
	and edx, 0x00FFFFFC		; Clear bits 31 - 24, 1 - 0
	or edx, 0x80000000		; Set bit 31
	mov eax, edx			; We need dx so save value to EAX for use
	ret
; -----------------------------------------------------------------------------


; Configuration Mechanism One has two IO port rages associated with it.
; The address port (0xCF8-0xCFB) and the data port (0xCFC-0xCFF).
; A configuration cycle consists of writing to the address port to specify which device and register you want to access and then reading or writing the data to the data port.

PCI_CONFIG_ADDRESS	EQU	0x0CF8
PCI_CONFIG_DATA		EQU	0x0CFC

; Address dd 10000000000000000000000000000000b
;            /\     /\      /\   /\ /\    /\
;           E  Res    Bus     Dev  F  Reg   0
; Bits
; 31		Enable bit = set to 1
; 30 - 24	Reserved = set to 0
; 23 - 16	Bus number = 256 options
; 15 - 11	Device/Slot number = 32 options
; 10 - 8	Function number = 8 options
; 7 - 2		Register number = 64 options, 64 x 4 bytes = 256 bytes worth of accessible registers
; 1 - 0		Set to 0


; =============================================================================
; EOF
