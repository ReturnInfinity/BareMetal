; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2017 Return Infinity -- see LICENSE.TXT
;
; Disk Block Storage Functions
; =============================================================================


; NOTE: BareMetal uses 4096 byte sectors.


; -----------------------------------------------------------------------------
; b_disk_read -- Read sectors from the disk
; IN:	RAX = Starting sector
;	RCX = Number of sectors to read
;	RDX = Disk
;	RDI = Memory location to store data
; OUT:	RCX = Number of sectors read
;	All other registers preserved
b_disk_read:
	push rdi
	push rcx
	push rax

	cmp byte [os_DiskEnabled], 1	; Make sure that a disk is present
	jne b_disk_read_error

	cmp rcx, 0
	je b_disk_read_error		; Bail out if instructed to read nothing
	shl rax, 3			; Convert to 512B starting sector

b_disk_read_loop:			; Read one sector at a time
	push rcx
	mov rcx, 8			; 8 512B sectors = 1 4K sector
	call ahci_read			; Driver deals with 512B sectors
	pop rcx
	sub rcx, 1
	jnz b_disk_read_loop

b_disk_read_done:
	pop rax
	pop rcx
	pop rdi
	ret

b_disk_read_error:
	pop rax
	pop rcx
	pop rdi
	xor ecx, ecx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_disk_write -- Write sectors to the disk
; IN:	RAX = Starting sector
;	RCX = Number of sectors to write
;	RDX = Disk
;	RSI = Memory location of data
; OUT:	RCX = Number of sectors written
;	All other registers preserved
b_disk_write:
	push rsi
	push rcx
	push rax

	cmp byte [os_DiskEnabled], 1	; Make sure that a disk is present
	jne b_disk_write_error

	cmp rcx, 0
	je b_disk_write_error		; Bail out if instructed to write nothing
	shl rax, 3			; Convert to 512B starting sector

b_disk_write_loop:			; Write one sector at a time
	push rcx
	mov rcx, 8			; 8 512B sectors = 1 4K sector
	call ahci_write			; Driver deals with 512B sectors
	pop rcx
	sub rcx, 1
	jnz b_disk_write_loop

b_disk_write_done:
	pop rax
	pop rcx
	pop rsi
	ret

b_disk_write_error:
	pop rax
	pop rcx
	pop rsi
	xor ecx, ecx
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
