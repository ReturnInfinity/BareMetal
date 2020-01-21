; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2020 Return Infinity -- see LICENSE.TXT
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

	cmp rcx, 0
	je b_disk_read_fail		; Bail out if instructed to read nothing
	shl rax, 3			; Convert to 512B starting sector
	shl rcx, 3			; Convert 4K sectors to 512B sectors

b_disk_read_loop:
	cmp rcx, 8192			; We can read up to 8192 512B sectors with one call
	jl b_disk_read_remainder
	push rcx
	mov rcx, 8192
	call ahci_read
	pop rcx
	sub rcx, 8192
	jnz b_disk_read_loop
	jmp b_disk_read_done
b_disk_read_remainder:
	call ahci_read

b_disk_read_done:
	pop rax
	pop rcx
	pop rdi
	ret

b_disk_read_fail:
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

	cmp rcx, 0
	je b_disk_write_fail		; Bail out if instructed to write nothing
	shl rax, 3			; Convert to 512B starting sector
	shl rcx, 3			; Convert 4K sectors to 512B sectors

b_disk_write_loop:
	cmp rcx, 8192			; We can write up to 8192 512B sectors with one call
	jl b_disk_write_remainder
	push rcx
	mov rcx, 8192
	call ahci_write
	pop rcx
	sub rcx, 8192
	jnz b_disk_write_loop
	jmp b_disk_write_done
b_disk_write_remainder:
	call ahci_write

b_disk_write_done:
	pop rax
	pop rcx
	pop rsi
	ret

b_disk_write_fail:
	pop rax
	pop rcx
	pop rsi
	xor ecx, ecx
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
