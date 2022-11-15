; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2022 Return Infinity -- see LICENSE.TXT
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
	push rbx
	push rax

	cmp rcx, 0
	je b_disk_read_fail		; Bail out if instructed to read nothing
	cmp rdx, 100
	jge b_disk_read_nvme

b_disk_read_ahci:
	mov ebx, AHCI_Read
	call ahci_io

b_disk_read_done:
	pop rax
	pop rbx
	pop rcx
	pop rdi
	ret

b_disk_read_nvme:
	sub rdx, 99			; To BareMetal the first NVMe drive is 100. Internally it is 1
	mov ebx, NVMe_Read
	call nvme_io
	add rdx, 99
	jmp b_disk_read_done

b_disk_read_fail:
	pop rax
	pop rbx
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
	push rbx
	push rax

	cmp rcx, 0
	je b_disk_write_fail		; Bail out if instructed to write nothing
	cmp rdx, 100
	jge b_disk_write_nvme

b_disk_write_ahci:
	mov ebx, AHCI_Write
	call ahci_io

b_disk_write_done:
	pop rax
	pop rbx
	pop rcx
	pop rsi
	ret

b_disk_write_nvme:
	sub rdx, 99			; To BareMetal the first NVMe drive is 100. Internally it is 1
	mov ebx, NVMe_Write
	call nvme_io
	add rdx, 99
	jmp b_disk_write_done

b_disk_write_fail:
	pop rax
	pop rbx
	pop rcx
	pop rsi
	xor ecx, ecx
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
