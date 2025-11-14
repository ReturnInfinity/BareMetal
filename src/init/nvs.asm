; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Initialize non-volatile storage
; =============================================================================


; -----------------------------------------------------------------------------
; init_nvs -- Configure the first non-volatile storage device it finds
init_nvs:

	; Output progress via serial
	mov rsi, msg_nvs
	call os_debug_string

%ifndef NO_NVME
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
%endif

	; Check Bus Table for any other supported controllers
	mov rsi, bus_table		; Load Bus Table address to RSI
	sub rsi, 16
	add rsi, 8			; Add offset to Class Code
init_nvs_check_bus:
	add rsi, 16			; Increment to next record in memory
	mov ax, [rsi]			; Load Class Code / Subclass Code
	cmp ax, 0xFFFF			; Check if at end of list
	je init_nvs_done		; No storage controller found
%ifndef NO_AHCI
	cmp ax, 0x0106			; Mass Storage Controller (01) / SATA Controller (06)
	je init_nvs_ahci
%endif
%ifndef NO_VIRTIO
	cmp ax, 0x0100			; Mass Storage Controller (01) / SCSI storage controller (00)
	je init_nvs_virtio_blk
%endif
	jmp init_nvs_check_bus		; Check Bus Table again

%ifndef NO_NVME
init_nvs_nvme:
	sub rsi, 8			; Move RSI back to start of Bus record
	mov edx, [rsi]			; Load value for os_bus_read/write
	call nvme_init
	jmp init_nvs_done
%endif

%ifndef NO_AHCI
init_nvs_ahci:
	sub rsi, 8			; Move RSI back to start of Bus record
	mov edx, [rsi]			; Load value for os_bus_read/write
	call ahci_init
	jmp init_nvs_done
%endif

%ifndef NO_VIRTIO
init_nvs_virtio_blk:
	sub rsi, 8			; Move RSI back to start of Bus record
	mov edx, [rsi]			; Load value for os_bus_read/write
	call virtio_blk_init
	jmp init_nvs_done
%endif

init_nvs_done:

%ifndef NO_LFB
	; Output block to screen (5/8)
	mov ebx, 8
	call os_debug_block
%endif

	; Output progress via serial
	mov rsi, msg_ok
	call os_debug_string

	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
