; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; PCI Express Functions
; =============================================================================


; See syscalls/bus.asm for description on RDX format
;
; os_pcie_convert uses the PCIe Table to find the correct memory address
;
; ┌───────────────────────────────────────────────────────────────────┐
; │                         PCIe Table Format                         │
; ├───┬───────────────────────────────────────────────────────────────┤
; │0x0│                       PCIe Base Memory                        │
; ├───┼───────────────┬───────┬───────┬───────────────────────────────┤
; │0x8│ Group Segment │ Start │  End  │               0               │
; └───┴───────────────┴───────┴───────┴───────────────────────────────┘
;
; Bytes 0-7	Base memory address for a PCIe host bridge
; Bytes 8-9	This PCIe Group Segment Number for this host bridge
; Byte 10	Start PCI bus number decoded by this host bridge
; Byte 11	End PCI bus number decoded by this host bridge
; Bytes 12-15	0
;
; The last record will contain all 0xFF's


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
; OUT:	RDX = Memory address of register
;	All other registers preserved
os_pcie_convert:
	push rsi
	push rax

	; Check the submitted Segment Group against known ones
	mov rsi, 0x5408			; Start of the PCIe info, offset to PCIe Segment Group at 0x8
	ror rdx, 32			; Rotate PCIe Segment Group to DX
os_pcie_convert_check_segment:
	mov ax, [rsi]			; Load a known PCIe Segment Group
	cmp ax, dx			; Compare the known value to what was provided
	je os_pcie_convert_valid
	cmp ax, 0xFFFF			; Compare to the end of the list value
	je os_pcie_convert_invalid
	add rsi, 16			; Increment to the next record
	jmp os_pcie_convert_check_segment

os_pcie_convert_valid:
	sub rsi, 8			; Set RSI to the location of the memory address at 0x0
	mov rsi, [rsi]			; Load the memory address to RSI
	rol rdx, 32			; Rotate PCIe Segment Group back to upper bits
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

os_pcie_convert_invalid:
	xor edx, edx
	not rdx				; Set RDX to 0xFFFFFFFFFFFFFFFF
	pop rax
	pop rsi
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
