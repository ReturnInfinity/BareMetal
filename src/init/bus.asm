; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Initialize Bus
; =============================================================================


; Build a table of known devices on the system bus
;
; ┌───────────────────────────────────────────────────────────────────┐
; │                         Bus Table Format                          │
; ├───┬───────────────────────────────┬───────────────┬───────────────┤
; │0x0│     Base Value for bus_*      │   Vendor ID   │   Device ID   │
; ├───┼───────┬───────┬───────────────┴───────────────┴───────────────┤
; │0x8│ Class │ SubCl │                     Flags                     │
; └───┴───────┴───────┴───────────────────────────────────────────────┘
;
; Bytes 0-3	Base value used for os_bus_read/write (SG SG BS DF)
; Bytes 4-5	Vendor ID
; Bytes 6-7	Device ID
; Byte 8	Class code
; Byte 9	Subclass code
; Bytes 10-15	Flags
; Byte 14 is the bus type (1 for PCI, 2 for PCIe)
; Byte 15 will be set to 0x01 later if a driver enabled it


; -----------------------------------------------------------------------------
init_bus:
	mov rdi, bus_table		; Address of Bus Table in memory
	xor edx, edx			; Register 0 for Device ID/Vendor ID

	; Check for PCIe first
	mov cx, [os_pcie_count]		; Check for PCIe
	cmp cx, 0
	jz init_bus_pci			; Fall back to PCI if no PCIe was detected
	mov byte [os_BusEnabled], 2	; Bit 1 set for PCIe

	; TODO
	; Check which PCIe segments are valid and process only those
	; For now we will only check against PCIe segment 0

init_bus_pcie_probe:
	call os_pcie_read		; Read a Device ID/Vendor ID
	cmp eax, 0xFFFFFFFF		; 0xFFFFFFFF is returned for an non-existent device
	je init_bus_pcie_probe_next	; Skip to next device

init_bus_pcie_probe_found:
	push rax			; Save the result
	mov rax, rdx			; Move the value used for os_pcie_read to RAX
	stosd				; Store it to the Bus Table
	pop rax				; Restore the Device ID/Vendor ID
	stosd				; Store it to the Bus Table
	add edx, 2			; Register 2 for Class code/Subclass/Prog IF/Revision ID
	call os_pcie_read
	shr eax, 16			; Move the Class/Subclass code to AX
	stosd				; Store it to the Bus Table
	sub edx, 2
	xor eax, eax			; Pad the Bus Table to 16 bytes
	stosw
	bts ax, 1			; Set bit for PCIe
	stosw

init_bus_pcie_probe_next:
	add rdx, 0x00010000		; Skip to next PCIe device/function
	cmp edx, 0			; Overflow EDX for a maximum of 65536 devices per segment
	je init_bus_end
	jmp init_bus_pcie_probe

init_bus_pci:
	mov eax, 0x80000000
	mov dx, PCI_CONFIG_ADDRESS
	out dx, eax
	in eax, dx
	cmp eax, 0x80000000
	jne init_bus_pci_not_found	; Exit if PCI wasn't found
	mov byte [os_BusEnabled], 1	; Bit 0 set for PCI
	xor edx, edx

init_bus_pci_probe:
	call os_pci_read		; Read a Device ID/Vendor ID
	cmp eax, 0xFFFFFFFF		; 0xFFFFFFFF is returned for an non-existent device
	jne init_bus_pci_probe_found	; Found a device
init_bus_pci_probe_next:
	add edx, 0x00010000		; Skip to next PCI device
	cmp edx, 0			; Overflow EDX for a maximum of 65536 devices
	je init_bus_end
	jmp init_bus_pci_probe

init_bus_pci_probe_found:
	push rax			; Save the result
	mov rax, rdx			; Move the value used for os_pci_read to RAX
	stosd				; Store it to the Bus Table
	pop rax				; Restore the Device ID/Vendor ID
	stosd				; Store it to the Bus Table
	add edx, 2			; Register 2 for Class code/Subclass/Prog IF/Revision ID
	call os_pci_read
	shr eax, 16			; Move the Class/Subclass code to AX
	stosd				; Store it to the Bus Table
	sub edx, 2
	xor eax, eax			; Pad the Bus Table to 16 bytes
	stosw
	bts ax, 0			; Set bit for PCI
	stosw
	jmp init_bus_pci_probe_next

init_bus_pci_not_found:
	ret

init_bus_end:
	mov eax, 0xFFFFFFFF
	mov ecx, 4
	rep stosd

	; Output block to screen (3/8)
	mov ebx, 4
	call os_debug_block

init_bus_usb_search:
	; Check Bus Table for a USB Controller
	mov rsi, bus_table		; Load Bus Table address to RSI
	sub rsi, 16
	add rsi, 8			; Add offset to Class Code
init_bus_usb_check:
	add rsi, 16			; Increment to next record in memory
	mov ax, [rsi]			; Load Class Code / Subclass Code
	cmp ax, 0xFFFF			; Check if at end of list
	je init_bus_usb_not_found
	cmp ax, 0x0C03			; Serial Bus Controller (0C) / USB Controller (03)
	je init_bus_usb_find_driver
	jmp init_bus_usb_check		; Check Bus Table again

	; Check the USB Controller to see if it is supported
init_bus_usb_find_driver:
	sub rsi, 8			; Move RSI back to start of Bus record
	mov edx, [rsi]			; Load value for os_bus_read/write
	mov dl, 0x02
	call os_bus_read
	shr eax, 8			; Shift Program Interface to AL
	cmp al, 0x30			; PI for XHCI
	je init_bus_usb_xhci_start
	add rsi, 8
	jmp init_bus_usb_check

init_bus_usb_xhci_start:
	call xhci_init

init_bus_usb_not_found:

	; Output block to screen (4/8)
	mov ebx, 6
	call os_debug_block

	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
