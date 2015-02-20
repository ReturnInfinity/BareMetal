; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2015 Return Infinity -- see LICENSE.TXT
;
; Disk Block Storage Functions
; =============================================================================


; -----------------------------------------------------------------------------
; os_disk_read --
; IN:	RAX = Starting block
;	RCX = Number of blocks
;	RDX = Disk
;	RDI = Memory location to store data
; OUT:
os_disk_read:
	cmp rcx, 0
	je os_disk_read_done		; Bail out if instructed to read nothing

	; Calculate the starting sector
	shl rax, 12			; Multiply block start count by 4096 to get sector start count

	; Calculate sectors to read
	shl rcx, 12			; Multiply block count by 4096 to get number of sectors to read
	mov rbx, rcx

os_disk_read_loop:
	mov rcx, 4096			; Read 2MiB at a time (4096 512-byte sectors = 2MiB)
	call readsectors
	sub rbx, 4096
	jnz os_disk_read_loop

os_disk_read_done:
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_disk_write --
; IN:	RAX = Starting block
;	RCX = Number of blocks
;	RDX = Disk
;	RSI = Memory location of data
; OUT:
os_disk_write:
	cmp rcx, 0
	je os_disk_write_done		; Bail out if instructed to write nothing

	; Calculate the starting sector
	shl rax, 12			; Multiply block start count by 4096 to get sector start count

	; Calculate sectors to write
	shl rcx, 12			; Multiply block count by 4096 to get number of sectors to write
	mov rbx, rcx

os_disk_write_loop:
	mov rcx, 4096			; Write 2MiB at a time (4096 512-byte sectors = 2MiB)
	call writesectors
	sub rbx, 4096
	jnz os_disk_write_loop

os_disk_write_done:
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
