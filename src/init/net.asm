; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; Initialize network
; =============================================================================


; -----------------------------------------------------------------------------
; init_net -- Configure the first network device it finds
init_net:
	; Check PCI Table for a Ethernet device
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
	jmp init_net_check_pci		; Check PCI Table again

	; Check the Ethernet device to see if it has a driver
init_net_probe_find_driver:
	sub rsi, 8			; Move RSI back to start of PCI record
	mov edx, [rsi]			; Load value for os_bus_read/write
	mov r8d, [rsi+4]		; Save the Device ID / Vendor ID in R8D
	rol r8d, 16			; Swap the Device ID / Vendor ID
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
	cmp bx, 0x8254
	je init_net_probe_found_i8254x
	cmp bx, 0x1AF4
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
	xor eax, eax
	mov al, [os_NetIRQ]
	mov ecx, eax
	add eax, 0x20			; Offset to start of Interrupts
;	call os_ioapic_mask_clear
	push rcx
	push rax
	shl ecx, 1			; Quick multiply by 2
	add ecx, IOAPICREDTBL		; Add offset
	bts eax, 13			; Active low
	bts eax, 15			; Level
	call os_ioapic_write		; Write the low 32 bits
	add ecx, 1			; Increment for next register
	xor eax, eax
	call os_ioapic_write		; Write the high 32 bits
	pop rax
	pop rcx

	mov byte [os_NetEnabled], 1	; A supported NIC was found. Signal to the OS that networking is enabled
	call b_net_ack_int		; Call the driver function to acknowledge the interrupt internally

init_net_probe_not_found:

	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
