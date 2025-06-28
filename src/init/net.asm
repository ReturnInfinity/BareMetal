; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Initialize network
; =============================================================================


; -----------------------------------------------------------------------------
; init_net -- Configure the first network device it finds
init_net:
	; Check Bus Table for a Ethernet device
	mov rsi, bus_table		; Load Bus Table address to RSI
	sub rsi, 8			; Subtract offset for Class Code
init_net_check_bus:
	add rsi, 16			; Increment to next record in memory
	mov ax, [rsi]			; Load Class Code / Subclass Code
	cmp ax, 0xFFFF			; Check if at end of list
	je init_net_probe_not_found
	cmp ax, 0x0200			; Network Controller (02) / Ethernet (00)
	je init_net_probe_find_driver
	jmp init_net_check_bus		; Check Bus Table again

	; Check the Ethernet device to see if it has a driver
init_net_probe_find_driver:
	sub rsi, 8			; Move RSI back to start of Bus record
	mov r9, rsi			; Save start of Bus record
	mov edx, [rsi]			; Load value for os_bus_read/write
	mov r8d, [rsi+4]		; Save the Device ID / Vendor ID in R8D
	rol r8d, 16			; Swap the Device ID / Vendor ID
	add rsi, 8			; Move RSI back to Class Code
	push rsi
	mov rsi, NIC_DeviceVendor_ID
init_net_probe_find_next_driver:
	lodsw				; Load a driver ID
	mov bx, ax			; Save the driver ID
	lodsw				; Load the vendor ID
	cmp eax, 0			; Check for a 0x0000 driver and vendor ID
	je init_net_probe_not_found
	rol eax, 16			; Shift the vendor to the upper 16 bits
init_net_probe_find_next_device:
	lodsw				; Load a device and vendor ID from our list of supported NICs
	cmp ax, 0x0000			; Check for end of device list
	je init_net_probe_find_next_driver	; We found the next driver type
	cmp eax, r8d
	je init_net_probe_found		; If Carry is clear then we found a supported NIC
	jmp init_net_probe_find_next_device	; Check the next device
init_net_probe_found:
	pop rsi
	cmp bx, 0x1AF4
	je init_net_probe_found_virtio
	cmp bx, 0x8254
	je init_net_probe_found_i8254x
	cmp bx, 0x8257
	je init_net_probe_found_i8257x
	cmp bx, 0x8259
	je init_net_probe_found_i8259x
;	cmp bx, 0x8169
;	je init_net_probe_found_r8169
	jmp init_net_probe_not_found

init_net_probe_found_virtio:
	call net_virtio_init
	jmp init_net_probe_found_finish

init_net_probe_found_i8254x:
	call net_i8254x_init
	jmp init_net_probe_found_finish

init_net_probe_found_i8257x:
	call net_i8257x_init
	jmp init_net_probe_found_finish

init_net_probe_found_i8259x:
	call net_i8259x_init
	jmp init_net_probe_found_finish

;init_net_probe_found_r8169:
;	call net_r8169_init
;	jmp init_net_probe_found_finish

init_net_probe_found_finish:
	mov byte [os_NetEnabled], 1	; A supported NIC was found. Signal to the OS that networking is enabled
	add r9, 15			; Add offset to driver enabled byte
	mov byte [r9], 1		; Mark device as having a driver
	add byte [os_net_icount], 1
	cmp byte [os_net_icount], 2	; Have 2 NIC's been activated?
	je init_net_end			; If so, bail out as 2 is the max at the moment
	jmp init_net_check_bus		; Check for another network device

init_net_probe_not_found:

init_net_end:
	; Output block to screen (6/8)
	mov ebx, 10
	call os_debug_block

	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
