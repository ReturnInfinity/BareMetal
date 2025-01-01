; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; ATA Driver
; =============================================================================


; NOTES:
;
; ATA is a legacy technology and, ideally, should not be used - ever
; It is here strictly to support disk access under Bochs
;
; These functions use LBA28. Maximum visible drive size is 128GiB
; LBA48 would be needed to access sectors over 128GiB (up to 128PiB)
;
; These functions are hard coded to access the Primary Master HDD only


; -----------------------------------------------------------------------------
ata_init:
	bts word [os_StorageVar], 2	; Set the bit flag that ATA has been initialized
	mov rdi, os_storage_io
	mov rax, ata_io
	stosq
	mov rax, ata_id
	stosq
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; ata_io -- Perform an I/O operation on an IDE device
; IN:	RAX = starting sector # (28-bit LBA address)
;	RBX = I/O Opcode
;	RCX = number of sectors
;	RDX = drive #
;	RDI = memory location used for reading/writing data from/to device
; OUT:	Nothing
;	All other registers preserved
ata_io:
	push rdi
	push rdx
	push rcx
	push rbx
	push rax

	shl rcx, 3		; Quick multiply by 8 as BareMetal deals in 4K sectors
	shl rax, 3		; Same for the starting sector number
	push rcx		; Save RCX for use in the read loop
	mov rbx, rcx		; Store number of sectors to read

; A single request can read 128KiB
	cmp rcx, 256
	jg ata_io_fail	; Over 256? Fail!
; TODO - Don't fail. Break the read into multiple requests
	jne ata_io_skip	; Not 256? No need to modify CL
	xor rcx, rcx		; 0 translates to 256
ata_io_skip:

	push rax		; Save sector number
	mov dx, ATA_PSC		; 0x01F2 - Sector count Port 7:0
	mov al, cl		; Read CL sectors
	out dx, al
	pop rax			; Restore number number
	inc dx			; 0x01F3 - LBA Low Port 7:0
	out dx, al
	inc dx			; 0x01F4 - LBA Mid Port 15:8
	shr rax, 8
	out dx, al
	inc dx			; 0x01F5 - LBA High Port 23:16
	shr rax, 8
	out dx, al
	inc dx			; 0x01F6 - Device Port. Bit 6 set for LBA mode, Bit 4 for device (0 = master, 1 = slave), Bits 3-0 for LBA "Extra High" (27:24)
	shr rax, 8
	and al, 00001111b 	; Clear bits 4-7 just to be safe
	or al, 01000000b	; Turn bit 6 on since we want to use LBA addressing, leave device at 0 (master)
	out dx, al
	inc dx			; 0x01F7 - Command Port
	mov al, 0x20		; Read sector(s). 0x24 if LBA48
	out dx, al

	mov rcx, 4
ata_io_wait:
	in al, dx		; Read status from 0x01F7
	test al, 0x80		; BSY flag set?
	jne ata_io_retry
	test al, 0x08		; DRQ set?
	jne ata_io_dataready
ata_io_retry:
	dec rcx
	jg ata_io_wait
ata_io_nextsector:
	in al, dx		; Read status from 0x01F7
	test al, 0x80		; BSY flag set?
	jne ata_io_nextsector
	test al, 0x21		; ERR or DF set?
	jne ata_io_fail

ata_io_dataready:
	sub dx, 7		; Data port (0x1F0)
	mov rcx, 256		; Read 
	rep insw		; Copy a 512 byte sector to RDI
	add dx, 7		; Set DX back to status register (0x01F7)
	in al, dx		; Delay ~400ns to allow drive to set new values of BSY and DRQ
	in al, dx
	in al, dx
	in al, dx

	dec rbx			; RBX is the "sectors to read" counter
	cmp rbx, 0
	jne ata_io_nextsector

	pop rcx
	pop rax
	inc rax
	pop rbx
	pop rcx
	pop rdx
	pop rdi
	ret

ata_io_fail:
	pop rcx
	pop rax
	pop rbx
	pop rcx
	pop rdx
	pop rdi
	xor rcx, rcx		; Set RCX to 0 since nothing was read
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; ata_id -- Perform an ID operation on an IDE device
; IN:	RAX = starting sector # (28-bit LBA address)
;	RBX = I/O Opcode
;	RCX = number of sectors
;	RDX = drive #
;	RDI = memory location used for reading/writing data from/to device
; OUT:	Nothing
;	All other registers preserved
ata_id:
	ret
; -----------------------------------------------------------------------------


; Port Registers
ATA_PDATA	equ 0x1F0
ATA_PERR	equ 0x1F0
ATA_PFEAT	equ 0x1F1
ATA_PSC		equ 0x1F2
ATA_LBALO	equ 0x1F3
ATA_LBAMID	equ 0x1F4
ATA_LBAHI	equ 0x1F5
ATA_PHEAD	equ 0x1F6
ATA_PSTATUS	equ 0x1F7
ATA_PCMD	equ 0x1F7

; Opcodes for IDE Commands
ATA_Write	equ 0x30
ATA_Read	equ 0x20
ATA_Identify	equ 0xEC


; =============================================================================
; EOF