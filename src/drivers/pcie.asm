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
	push rdx

	call os_pcie_convert		; Convert RDX to memory address
	mov eax, [rdx]			; Load register value

	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_pcie_write -- Write to a register on a PCIe device
;  IN:	RDX = Register to write to
;	EAX = Register value to be written
; OUT:	Nothing, all registers preserved
os_pcie_write:
	push rdx

	call os_pcie_convert		; Convert RDX to memory address
	mov [rdx], eax			; Store register value

	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_pcie_convert -- Convert RDX to the memory address of the register
;  IN:	RDX = Register to read/write
;	RDX = Memory address of register
; OUT:	Nothing, all registers preserved
os_pcie_convert:
	push rsi
	push rax

	; Check the submitted Segment Group against known ones
	mov rsi, [0x5400]
	
	; Add offset to the correct device/function/register
	push rdx			; Save RDX for the register
	and edx, 0xFFFF0000		; Isolate the device/function
	shr edx, 4			; Quick divide by 16
	add rsi, rdx			; RSI now points to the start of the 4KB register memory
	pop rdx				; Low 10 bits of RDX is the register
	and edx, 0x000003FF		; Only keep the low 10 bits
	shl edx, 2			; Quick multiply by 4
	add rsi, rdx			; Add offset for the register
	mov rdx, rsi			; Store final memory address in RDX

	pop rax
	pop rsi
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
