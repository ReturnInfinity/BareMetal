; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Initialize non-volatile storage
; =============================================================================


; -----------------------------------------------------------------------------
; init_nvs -- Configure the first non-volatile storage device it finds
init_nvs:
	; Check Bus Table for NVMe
	mov rsi, bus_table		; Load Bus Table address to RSI
	sub rsi, 16
	add rsi, 8			; Add offset to Class Code
init_nvs_nvme_check:
	add rsi, 16			; Increment to next record in memory
	mov ax, [rsi]			; Load Class Code / Subclass Code
	cmp ax, 0xFFFF			; Check if at end of list
	je init_nvs_nvme_skip		; If no NVMe the bail out
	cmp ax, 0x0108			; Mass Storage Controller (01) / NVMe Controller (08)
	je init_nvs_nvme
	jmp init_nvs_nvme_check		; Check Bus Table again
init_nvs_nvme_skip:

	; Check Bus Table for any other supported controllers
	mov rsi, bus_table		; Load Bus Table address to RSI
	sub rsi, 16
	add rsi, 8			; Add offset to Class Code
init_nvs_check_bus:
	add rsi, 16			; Increment to next record in memory
	mov ax, [rsi]			; Load Class Code / Subclass Code
	cmp ax, 0xFFFF			; Check if at end of list
	je init_nvs_done		; No storage controller found
	cmp ax, 0x0101			; Mass Storage Controller (01) / ATA Controller (01)
	je init_nvs_ata	
	cmp ax, 0x0106			; Mass Storage Controller (01) / SATA Controller (06)
	je init_nvs_ahci
	cmp ax, 0x0100			; Mass Storage Controller (01) / SCSI storage controller (00)
	je init_nvs_virtio_blk
	jmp init_nvs_check_bus		; Check Bus Table again

init_nvs_nvme:
	sub rsi, 8			; Move RSI back to start of Bus record
	mov edx, [rsi]			; Load value for os_bus_read/write
	call nvme_init
	jmp init_nvs_done

init_nvs_ahci:
	sub rsi, 8			; Move RSI back to start of Bus record
	mov edx, [rsi]			; Load value for os_bus_read/write
	call ahci_init
	jmp init_nvs_done

init_nvs_virtio_blk:
	sub rsi, 8			; Move RSI back to start of Bus record
	mov edx, [rsi]			; Load value for os_bus_read/write
	call virtio_blk_init
	jmp init_nvs_done

init_nvs_ata:
	sub rsi, 8			; Move RSI back to start of Bus record
	mov edx, [rsi]			; Load value for os_bus_read/write
	call ata_init
	jmp init_nvs_done

init_nvs_done:
	; Output block to screen (5/8)
	mov ebx, 8
	call os_debug_block

	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
