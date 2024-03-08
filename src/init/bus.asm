; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; Initialize Bus (PCIe or PCI)
; =============================================================================


; Build a table of known PCIe/PCI devices
; Bytes 0-5	Base value used for os_bus_read/write (SG SG BS DF)
; Bytes 6-7	Vendor ID
; Bytes 8-9	Device ID
; Byte 10	Class code
; Byte 11	Subclass code
; Bytes 12-15	Cleared to 0x00
; Byte 15 will be set to 0x01 later if a driver enabled it


; -----------------------------------------------------------------------------
init_bus:
	; Check for PCIe first
	mov cx, [os_pcie_count]
	cmp cx, 0
	jz init_bus_pci
	mov byte [os_BusEnabled], 2	; Bit 1 set for PCIe

	mov rdi, pci_table		; Address of PCIe Table in memory
	xor edx, edx			; Register 0 for Device ID/Vendor ID

init_bus_pcie_probe:
	call os_pcie_read		; Read a Device ID/Vendor ID
	cmp eax, 0xFFFFFFFF		; 0xFFFFFFFF is returned for an non-existent device
	jne init_bus_pcie_probe_found	; Found a device
init_bus_pcie_probe_next:
	add edx, 0x00000100		; Skip to next PCIe device/function
	cmp edx, 0x0000FF00		; Maximum of 256 devices per bus
	jge init_bus_end
	jmp init_bus_pcie_probe

init_bus_pcie_probe_found:
	push rax			; Save the result
	; TODO Fix this
	mov rax, rdx			; Move the value used for os_pci_read to RAX
	stosd				; Store it to the PCI Table
	pop rax				; Restore the Device ID/Vendor ID
	stosd				; Store it to the PCI Table
	add edx, 1			; Register 2 for Class code/Subclass/Prog IF/Revision ID
	call os_pcie_read
	shr eax, 16			; Move the Class/Subclass code to AX
	stosd				; Store it to the PCI Table
	sub edx, 1
	xor eax, eax
	stosd				; Pad the PCI Table to 32 bytes
	jmp init_bus_pcie_probe_next

init_bus_pci:
	mov eax, 0x80000000
	mov dx, PCI_CONFIG_ADDRESS
	out dx, eax
	in eax, dx
	cmp eax, 0x80000000
	jne init_bus_pci_not_found	; Exit if PCI wasn't found
	mov byte [os_BusEnabled], 1

	mov rdi, pci_table		; Address of PCI Table in memory
	xor edx, edx			; Register 0 for Device ID/Vendor ID

init_bus_pci_probe:
	call os_pci_read		; Read a Device ID/Vendor ID
	cmp eax, 0xFFFFFFFF		; 0xFFFFFFFF is returned for an non-existent device
	jne init_bus_pci_probe_found	; Found a device
init_bus_pci_probe_next:
	add edx, 0x00000100		; Skip to next PCI device
	cmp edx, 0x00FFFF00		; Maximum of 65536 devices
	jge init_bus_end
	jmp init_bus_pci_probe

init_bus_pci_probe_found:
	push rax			; Save the result
	mov rax, rdx			; Move the value used for os_pci_read to RAX
	stosd				; Store it to the PCI Table
	pop rax				; Restore the Device ID/Vendor ID
	stosd				; Store it to the PCI Table
	add edx, 2			; Register 2 for Class code/Subclass/Prog IF/Revision ID
	call os_pci_read
	shr eax, 16			; Move the Class/Subclass code to AX
	stosd				; Store it to the PCI Table
	sub edx, 2
	xor eax, eax
	stosd				; Pad the PCI Table to 32 bytes
	jmp init_bus_pci_probe_next

init_bus_pci_not_found:
	ret

init_bus_end:
	mov eax, 0xFFFFFFFF
	mov ecx, 4
	rep stosd
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
