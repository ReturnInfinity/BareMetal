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
	lodsd
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

	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
