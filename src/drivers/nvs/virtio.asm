; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Virtio NVS Driver
; =============================================================================


; -----------------------------------------------------------------------------
nvs_virtio_init:
	push rsi
	push rdx			; RDX should already point to a supported device for os_bus_read/write
	push rbx
	push rax

	; Verify this driver supports the Vendor
	mov eax, [rsi+4]		; Offset to Vendor/Device ID in the Bus Table
	cmp ax, 0x1AF4			; Virtio Vendor ID
	jne nvs_virtio_init_done	; Bail out if it wasn't a match

	; Verify this driver support the Device
	shr eax, 16			; Move Device ID into AX
	cmp ax, 0x1001			; Virtio Block Device ID (legacy)
	je nvs_virtio_init_blk
	cmp ax, 0x1042			; Virtio Block Device ID
	je nvs_virtio_init_blk
	cmp ax, 0x1004			; Virtio SCSI Device ID (legacy)
	je nvs_virtio_init_scsi
	cmp ax, 0x1048			; Virtio SCSI Device ID
	je nvs_virtio_init_scsi
	jmp nvs_virtio_init_done	; Bail out if no supported devices were found

nvs_virtio_init_blk:
	call nvs_virtio_blk_init
	jmp nvs_virtio_init_done

nvs_virtio_init_scsi:
	call nvs_virtio_scsi_init

nvs_virtio_init_done:
	pop rax
	pop rbx
	pop rdx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF