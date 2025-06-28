; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Virtio Input Driver
; =============================================================================


; -----------------------------------------------------------------------------
virtio_input_init:
	mov ebx, [virtio_input_driverid]
	mov rsi, bus_table
	add rsi, 4
virtio_input_init_search:
	mov eax, [rsi]
	cmp eax, 0xFFFFFFFF
	je virtio_input_init_done
	cmp eax, ebx
	je virtio_input_init_config
	add rsi, 16
	jmp virtio_input_init_search

virtio_input_init_config:
	sub rsi, 4
	mov edx, [rsi]

	mov eax, 4			; Read BAR4
	call os_bus_read_bar
	mov [os_virtio_input_base], rax	; Save it as the base
	mov rsi, rax			; RSI holds the base for MMIO

	; Set PCI Status/Command values
	mov dl, 0x01			; Read Status/Command
	call os_bus_read
	bts eax, 10			; Set Interrupt Disable
	bts eax, 2			; Enable Bus Master
	bts eax, 1			; Enable Memory Space
	call os_bus_write		; Write updated Status/Command

	; Device Initialization (section 3.1)

	; 3.1.1 - Step 1 -  Reset the device (section 2.4)
	mov al, 0x00			
	mov [rsi+VIRTIO_DEVICE_STATUS], al
virtio_input_init_reset_wait:
	mov al, [rsi+VIRTIO_DEVICE_STATUS]
	cmp al, 0x00
	jne virtio_input_init_reset_wait

	; 3.1.1 - Step 2 - Set the ACKNOWLEDGE bit - Tell the device we see it
	mov al, VIRTIO_STATUS_ACKNOWLEDGE
	mov [rsi+VIRTIO_DEVICE_STATUS], al

	; 3.1.1 - Step 3 - Set the DRIVER bit - Tell the device we support it
	mov al, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER
	mov [rsi+VIRTIO_DEVICE_STATUS], al

	; 3.1.1 - Step 4 - Read device feature bits and write supported driver bits back
	; Process the first 32-bits of Feature bits
	xor eax, eax
	mov [rsi+VIRTIO_DEVICE_FEATURE_SELECT], eax
	mov eax, [rsi+VIRTIO_DEVICE_FEATURE]
	push rax
	xor eax, eax
	mov [rsi+VIRTIO_DRIVER_FEATURE_SELECT], eax
	pop rax
	mov [rsi+VIRTIO_DRIVER_FEATURE], eax
	; Process the next 32-bits of Feature bits
	mov eax, 1
	mov [rsi+VIRTIO_DEVICE_FEATURE_SELECT], eax
	mov eax, [rsi+VIRTIO_DEVICE_FEATURE]
	and eax, 1
	push rax
	mov eax, 1
	mov [rsi+VIRTIO_DRIVER_FEATURE_SELECT], eax
	pop rax
	mov [rsi+VIRTIO_DRIVER_FEATURE], eax

	; 3.1.1 - Step 5 - Set the FEATURES_OK bit - Tell the device we will init with those features
	mov al, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_FEATURES_OK
	mov [rsi+VIRTIO_DEVICE_STATUS], al

	; 3.1.1 - Step 6 - Re-read device status to make sure FEATURES_OK is still set
	mov al, [rsi+VIRTIO_DEVICE_STATUS]
	bt ax, 3			; VIRTIO_STATUS_FEATURES_OK
	jnc virtio_input_init_error

	; 3.1.1 - Step 7
	; Set up the device and the queues
	; discovery of virtqueues for the device
	; optional per-bus setup
	; reading and possibly writing the device’s virtio configuration space
	; population of virtqueues

	; Set up Queue 0
	xor eax, eax
	mov [rsi+VIRTIO_QUEUE_SELECT], ax
	mov ax, [rsi+VIRTIO_QUEUE_SIZE]	; Return the size of the queue
	mov ecx, eax			; Store queue size in ECX
	mov eax, 0xA00000
	mov [rsi+VIRTIO_QUEUE_DESC], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DESC+8], eax
	rol rax, 32
	add rax, 4096
	mov [rsi+VIRTIO_QUEUE_DRIVER], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DRIVER+8], eax
	rol rax, 32
	add rax, 4096
	mov [rsi+VIRTIO_QUEUE_DEVICE], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DEVICE+8], eax
	rol rax, 32
	mov ax, 1
	mov [rsi+VIRTIO_QUEUE_ENABLE], ax

	; Populate the Next entries in the description ring
	; FIXME - Don't expect exactly 256 entries
	mov eax, 1
	mov rdi, 0xA00000
	add rdi, 14
virtio_input_init_pop:
	mov [rdi], al
	add rdi, 16
	add al, 1
	cmp al, 0
	jne virtio_input_init_pop

	; 3.1.1 - Step 8 - Set the DRIVER_OK bit - At this point the device is “live”
	mov al, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_DRIVER_OK | VIRTIO_STATUS_FEATURES_OK
	mov [rsi+VIRTIO_DEVICE_STATUS], al



	; DEBUG
;	mov r9, 0x1234
;	jmp $

virtio_input_init_done:
	ret

virtio_input_init_error:
	mov al, VIRTIO_STATUS_FAILED
	mov [rsi+VIRTIO_DEVICE_STATUS], al

	ret
; -----------------------------------------------------------------------------


; Driver
virtio_input_driverid:
dw 0x1AF4				; Vendor ID
dw 0x1052				; Device ID (0x1040 + 18)

; =============================================================================
; EOF