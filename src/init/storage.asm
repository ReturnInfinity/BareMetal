; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; Initialize storage
; =============================================================================


; -----------------------------------------------------------------------------
; init_storage -- Configure the first storage device it finds
init_storage:
	; Check PCI Table for a supported controller
	mov rsi, pci_table		; Load PCI Table address to RSI
	sub rsi, 16
	add rsi, 10			; Add offset to Class Code
init_storage_check_pci:
	add rsi, 16			; Increment to next record in memory
	mov ax, [rsi]			; Load Class Code / Subclass Code
	cmp ax, 0xFFFF			; Check if at end of list
	je init_storage_ata		; If no NVMe or AHCI was found, try ATA
	cmp ax, 0x0108			; Mass Storage Controller (01) / NVMe Controller (08)
	je init_storage_nvme
	cmp ax, 0x0106			; Mass Storage Controller (01) / SATA Controller (06)
	je init_storage_ahci

	jmp init_storage_check_pci	; Check PCI Table again

init_storage_nvme:
	sub rsi, 8			; Move RSI back to start of PCI record
	mov edx, [rsi]			; Load value for os_pci_read/write
	call nvme_init
	jmp init_storage_done

init_storage_ahci:
	sub rsi, 8			; Move RSI back to start of PCI record
	mov edx, [rsi]			; Load value for os_pci_read/write
	call ahci_init
	jmp init_storage_done

init_storage_ata:
	call ata_init	

init_storage_done:
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
