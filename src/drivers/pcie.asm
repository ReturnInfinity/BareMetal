; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; PCI Express Functions
; =============================================================================


; Maximum of 65536 segments, 16-bit
; Maximum of 256 buses, 8-bit
; Maximum of 32 devices/slots - 5 bits
; Maximum of 8 functions - 3 bits
; Maximum of 4096 bytes, 8-bit via 8-byte registers

; The PCIe functions below require the bus ID, device/function ID, and register
; ID to be passed in RDX as shown below:
;
; 0x 00 00 SG SG 00 BS DF RG
; SG = PCIe Segment Group, 16 bits
; BS = Bus, 8 bits
; DF = Device/Function, 8 bits
; RG = Register, 8 bits


; -----------------------------------------------------------------------------
; os_pcie_read -- Read from a register on a PCIe device
;  IN:	RDX = Register to read from
; OUT:	RAX = Register value that was read
;	All other registers preserved
os_pcie_read:
	push rsi
	push rdx
	; ror rdx, 32			; Move segment to DX
	; Load RSI with the base memory of the selected PCI Segment
	mov rsi, 0xb0000000		; QEMU

	push rdx
	and edx, 0x0000FF00		; Isolate the device/function
	shl edx, 4			; Quick multiply by 16
	add rsi, rdx			; RSI now points to the start of the 4KB register memory
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
;  IN:	RDX = Register to write to
;	RAX = Register value to be written
; OUT:	Nothing, all registers preserved
os_pcie_write:

	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
