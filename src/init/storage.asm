; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Initialize storage
; =============================================================================


; -----------------------------------------------------------------------------
; init_storage -- Configure the first storage device it finds
init_storage:
	; Debug output
	mov rsi, msg_init_sto
	mov rcx, 10
	call b_output

	; Check Bus Table for a supported controller
	mov rsi, bus_table		; Load Bus Table address to RSI
	sub rsi, 16
	add rsi, 8			; Add offset to Class Code
init_storage_check_bus:
	add rsi, 16			; Increment to next record in memory
	mov ax, [rsi]			; Load Class Code / Subclass Code
	cmp ax, 0xFFFF			; Check if at end of list
	je init_storage_ata		; If no NVMe or AHCI was found, try ATA
	cmp ax, 0x0108			; Mass Storage Controller (01) / NVMe Controller (08)
	je init_storage_nvme
	cmp ax, 0x0106			; Mass Storage Controller (01) / SATA Controller (06)
	je init_storage_ahci
	cmp ax, 0x0100			; Mass Storage Controller (01) / SCSI storage controller (00)
	je init_storage_virtio_blk
	jmp init_storage_check_bus	; Check Bus Table again

init_storage_nvme:
	sub rsi, 8			; Move RSI back to start of Bus record
	mov edx, [rsi]			; Load value for os_bus_read/write
	call nvme_init
	jmp init_storage_done

init_storage_ahci:
	sub rsi, 8			; Move RSI back to start of Bus record
	mov edx, [rsi]			; Load value for os_bus_read/write
	call ahci_init
	jmp init_storage_done

init_storage_virtio_blk:
	sub rsi, 8			; Move RSI back to start of Bus record
	mov edx, [rsi]			; Load value for os_bus_read/write
	call virtio_blk_init
	jmp init_storage_done

init_storage_ata:
	call ata_init	

init_storage_done:
	; Output block to screen (3/4)
	mov ebx, 4
	call os_debug_block

	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
