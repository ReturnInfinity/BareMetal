; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2015 Return Infinity -- see LICENSE.TXT
;
; Disk Block Storage Functions
; =============================================================================


; NOTE: BareMetal uses 4096 byte sectors.


; -----------------------------------------------------------------------------
; os_disk_read -- Read sectors from the disk
; IN:	RAX = Starting sector
;	RCX = Number of sectors
;	RDX = Disk
;	RDI = Memory location to store data
; OUT:	Nothing, all registers preserved
os_disk_read:
	push rdi
	push rcx
	push rax

	cmp rcx, 0
	je os_disk_read_done		; Bail out if instructed to read nothing
	shl rax, 8			; Convert to 512B starting sector

os_disk_read_loop:			; Read one sector at a time
	push rcx
	mov rcx, 8			; 8 512B sectors = 1 4K sector
	call readsectors		; Driver deals with 512B sectors
	pop rcx
	sub rcx, 1
	jnz os_disk_read_loop

os_disk_read_done:
	pop rax
	pop rcx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_disk_write -- Write sectors to the disk
; IN:	RAX = Starting sector
;	RCX = Number of sector
;	RDX = Disk
;	RSI = Memory location of data
; OUT:	Nothing, all registers preserved
os_disk_write:
	push rsi
	push rcx
	push rax

	cmp rcx, 0
	je os_disk_write_done		; Bail out if instructed to write nothing
	shl rax, 8			; Convert to 512B starting sector

os_disk_write_loop:			; Write one sector at a time
	push rcx
	mov rcx, 8			; 8 512B sectors = 1 4K sector
	call writesectors		; Driver deals with 512B sectors
	pop rcx
	sub rcx, 1
	jnz os_disk_write_loop

os_disk_write_done:
	pop rax
	pop rcx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
