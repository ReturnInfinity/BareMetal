; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; PCI Express Functions
; =============================================================================


; Maximum of 65536 buses, 16-bit
; Maximum of 256 devices per bus, 8-bit
; Maximum of 4096 bytes, 8-bit via 8-byte registers

; The PCI functions below require the bus ID, device/function ID, and register
; ID to be passed in EDX as shown below:
;
; 0x BS BS DF RG
; BS = Bus, 16 bits
; DF = Device/Function, 8 bits
; RG = Register, 8 bits


; -----------------------------------------------------------------------------
; os_pcie_read -- Read from a register on a PCIe device
;  IN:	EDX = Register to read from
; OUT:	RAX = Register value that was read
;	All other registers preserved
os_pcie_read:
	push rsi
	push rdx
	; TODO load the base properly based on the bus
	mov rsi, 0xb0000000		; QEMU
	push rdx
	and edx, 0x0000FF00		; Isolate the device/function
	shl edx, 4			; Quick multiply by 16
	add rsi, rdx
	pop rdx
	and edx, 0x000000FF
	shl edx, 3			; Quick multiply by 8
	add rsi, rdx
	push rax
	mov rax, rsi
	call os_debug_dump_rax
	pop rax
	lodsq
	pop rdx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_pcie_write -- Write to a register on a PCIe device
;  IN:	EDX = Register to write to
;	RAX = Register value to be written
; OUT:	Nothing, all registers preserved
os_pcie_write:

	ret
; -----------------------------------------------------------------------------


; Address dd 10000000000000000000000000000000b
;            /\     /\      /\   /\ /\    /\
;           E  Res    Bus     Dev  F  Reg   0
; Bits
; 31		Enable bit = set to 1
; 30 - 24	Reserved = set to 0
; 23 - 16	Bus number = 256 options
; 15 - 11	Device/Slot number = 32 options
; 10 - 8	Function number = will leave at 0 (8 options)
; 7 - 0		Register number = will leave at 0 (1024 options) 1024 x 4 bytes = 4096 bytes worth of accessible registers

; =============================================================================
; EOF
