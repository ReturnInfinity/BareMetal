; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2022 Return Infinity -- see LICENSE.TXT
;
; Storage Functions
; =============================================================================


; -----------------------------------------------------------------------------
; b_storage_read -- Read sectors from a drive
; IN:	RAX = Starting sector
;	RCX = Number of sectors to read
;	RDX = Drive
;	RDI = Memory address to store data
; OUT:	RCX = Number of sectors read
;	All other registers preserved
b_storage_read:
	push rdi
	push rcx
	push rbx
	push rax

	cmp rcx, 0
	je b_storage_read_fail		; Bail out if instructed to read nothing
	cmp rdx, 100
	jge b_storage_read_nvme

b_storage_read_ahci:
	mov ebx, AHCI_Read
	call ahci_io

b_storage_read_done:
	pop rax
	pop rbx
	pop rcx
	pop rdi
	ret

b_storage_read_nvme:
	sub rdx, 99			; To BareMetal the first NVMe drive is 100. Internally it is 1
	mov ebx, NVMe_Read
	call nvme_io
	add rdx, 99
	jmp b_storage_read_done

b_storage_read_fail:
	pop rax
	pop rbx
	pop rcx
	pop rdi
	xor ecx, ecx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_storage_write -- Write sectors to a drive
; IN:	RAX = Starting sector
;	RCX = Number of sectors to write
;	RDX = Drive
;	RSI = Memory address of data to store
; OUT:	RCX = Number of sectors written
;	All other registers preserved
b_storage_write:
	push rdi
	push rsi
	push rcx
	push rbx
	push rax

	mov rdi, rsi			; The I/O functions only use RDI for the memory address

	cmp rcx, 0
	je b_storage_write_fail		; Bail out if instructed to write nothing
	cmp rdx, 100
	jge b_storage_write_nvme

b_storage_write_ahci:
	mov ebx, AHCI_Write
	call ahci_io

b_storage_write_done:
	pop rax
	pop rbx
	pop rcx
	pop rsi
	pop rdi
	ret

b_storage_write_nvme:
	sub rdx, 99			; To BareMetal the first NVMe drive is 100. Internally it is 1
	mov ebx, NVMe_Write
	call nvme_io
	add rdx, 99
	jmp b_storage_write_done

b_storage_write_fail:
	pop rax
	pop rbx
	pop rcx
	pop rsi
	pop rdi
	xor ecx, ecx
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
