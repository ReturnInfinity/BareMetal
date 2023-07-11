; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2022 Return Infinity -- see LICENSE.TXT
;
; Initialize network
; =============================================================================


; -----------------------------------------------------------------------------
init_net:
	; Check PCI Table for a supported controller
	mov rsi, pci_table		; Load PCI Table address to RSI
	sub rsi, 16
	add rsi, 8			; Add offset to Class Code
init_net_check_pci:
	add rsi, 16			; Increment to next record in memory
	mov ax, [rsi]			; Load Class Code / Subclass Code
	cmp ax, 0xFFFF			; Check if at end of list
	je init_net_probe_not_found
	cmp ax, 0x0200			; Network Controller (02) / Ethernet (00)
	je init_net_probe_find_driver
	jmp init_net_check_pci	; Check PCI Table again

init_net_probe_find_driver:
	sub rsi, 8			; Move RSI back to start of PCI record
	mov edx, [rsi]			; Load value for os_pci_read/write
	mov r8d, [rsi+4]		; Save the Device ID / Vendor ID in R8D
	mov rsi, NIC_DeviceVendor_ID
	lodsd				; Load a driver ID - Low half must be 0xFFFF
init_net_probe_find_next_driver:
	mov rbx, rax			; Save the driver ID
init_net_probe_find_next_device:
	lodsd				; Load a device and vendor ID from our list of supported NICs
	test eax, eax			; 0x00000000 means we have reached the end of the list
	jz init_net_probe_not_found	; No supported NIC found
	cmp ax, 0xFFFF			; New driver ID?
	je init_net_probe_find_next_driver	; We found the next driver type
	cmp eax, r8d
	je init_net_probe_found		; If Carry is clear then we found a supported NIC
	jmp init_net_probe_find_next_device	; Check the next device

init_net_probe_found:
	cmp ebx, 0x8254FFFF
	je init_net_probe_found_i8254x
	cmp ebx, 0x1AF4FFFF
	je init_net_probe_found_virtio
	jmp init_net_probe_not_found

init_net_probe_found_i8254x:
	call net_i8254x_init
	mov rdi, os_net_transmit
	mov rax, net_i8254x_transmit
	stosq
	mov rax, net_i8254x_poll
	stosq
	mov rax, net_i8254x_ack_int
	stosq
	jmp init_net_probe_found_finish

init_net_probe_found_virtio:
	call net_virtio_init
	mov rdi, os_net_transmit
	mov rax, net_virtio_transmit
	stosq
	mov rax, net_virtio_poll
	stosq
	mov rax, net_virtio_ack_int
	stosq
	jmp init_net_probe_found_finish

init_net_probe_found_finish:
	xor eax, eax
	mov al, [os_NetIRQ]

	add al, 0x20
	mov rdi, rax
	mov rax, network
	call create_gate

	; Enable the Network IRQ
	mov al, [os_NetIRQ]
	call os_pic_mask_clear

	mov byte [os_NetEnabled], 1	; A supported NIC was found. Signal to the OS that networking is enabled
	call b_net_ack_int		; Call the driver function to acknowledge the interrupt internally

init_net_probe_not_found:

	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
