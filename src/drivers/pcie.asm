; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; PCI Express Functions
; =============================================================================


; See syscalls/bus.asm for description on RDX format


; -----------------------------------------------------------------------------
; os_pcie_read -- Read from a register on a PCIe device
;  IN:	RDX = Register to read from
; OUT:	EAX = Register value that was read
;	All other registers preserved
os_pcie_read:
	push rsi
	push rdx
	; ror rdx, 32			; Move segment to DX
	; Load RSI with the base memory of the selected PCIe Segment
	mov rsi, 0xb0000000		; QEMU

	push rdx			; Save RDX for the register
	and edx, 0xFFFF0000		; Isolate the device/function
	shr edx, 4			; Quick divide by 16
	add rsi, rdx			; RSI now points to the start of the 4KB register memory
	pop rdx				; Low 10 bits of RDX is the register
	and edx, 0x000003FF		; Only keep the low 10 bits
	shl edx, 2			; Quick multiply by 4
	add rsi, rdx			; Add offset for the register

	lodsd				; Load a 32-bit PCIe register

	pop rdx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_pcie_write -- Write to a register on a PCIe device
;  IN:	RDX = Register to write to
;	EAX = Register value to be written
; OUT:	Nothing, all registers preserved
os_pcie_write:
	push rdi
	push rdx
	; ror rdx, 32			; Move segment to DX
	; Load RDI with the base memory of the selected PCI Segment
	mov rdi, 0xb0000000		; QEMU

	push rdx			; Save RDX for the register
	and edx, 0xFFFF0000		; Isolate the device/function
	shr edx, 4			; Quick divide by 16
	add rdi, rdx			; RSI now points to the start of the 4KB register memory
	pop rdx				; Low 10 bits of RDX is the register
	and edx, 0x000003FF		; Only keep the low 10 bits
	shl edx, 2			; Quick multiply by 4
	add rdi, rdx			; Add offset for the register

	stosd				; Store a 32-bit PCIe register

	pop rdx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
