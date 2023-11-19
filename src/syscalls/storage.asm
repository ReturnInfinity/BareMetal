; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2023 Return Infinity -- see LICENSE.TXT
;
; Storage Functions
; =============================================================================


; -----------------------------------------------------------------------------
; b_storage_read -- Read sectors from a drive
; IN:	RAX = Starting sector
;	RCX = Number of sectors to read
;	RDX = Drive
;	RDI = Memory address to store data
; OUT:	RCX = Number of sectors read (0 on error)
;	All other registers preserved
b_storage_read:
	push rdi
	push rcx
	push rbx
	push rax

	; Calculate where in physical memory the data should be written to
	xchg rax, rdi
	call os_virt_to_phys
	xchg rax, rdi

	mov ebx, 2			; Read opcode for driver
	call [os_storage_io]		; Call the storage driver IO command

	pop rax
	pop rbx
	pop rcx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_storage_write -- Write sectors to a drive
; IN:	RAX = Starting sector
;	RCX = Number of sectors to write
;	RDX = Drive
;	RSI = Memory address of data to store
; OUT:	RCX = Number of sectors written (0 on error)
;	All other registers preserved
b_storage_write:
	push rdi
	push rsi
	push rcx
	push rbx
	push rax

	mov rdi, rsi			; The I/O functions only use RDI for the memory address

	; Calculate where in physical memory the data should be read from
	xchg rax, rsi
	call os_virt_to_phys
	xchg rax, rsi

	mov ebx, 1			; Write opcode for driver
	call qword [os_storage_io]	; Call the storage driver IO command

	pop rax
	pop rbx
	pop rcx
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
