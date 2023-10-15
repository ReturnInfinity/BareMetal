; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2023 Return Infinity -- see LICENSE.TXT
;
; Initialize PCI
; =============================================================================


; -----------------------------------------------------------------------------
init_pci:
	mov eax, 0x80000000
	mov dx, PCI_CONFIG_ADDRESS
	out dx, eax
	in eax, dx
	cmp eax, 0x80000000
	jne init_pci_not_found		; Exit if PCI wasn't found
	mov byte [os_PCIEnabled], 1

; Build a table of known PCI devices
; Bytes 0-3	Base PCI value used for os_pci_read/write (See PCI driver)
; Bytes 4-5	Vendor ID
; Bytes 6-7	Device ID
; Byte 8	Class code
; Byte 9	Subclass code
; Bytes 10-15	Cleared to 0x00
; Byte 15 will be set to 0x01 later if a driver enabled it

	mov rdi, pci_table		; Address of PCI Table in memory
	xor edx, edx			; Register 0 for Device ID/Vendor ID

init_pci_probe:
	call os_pci_read		; Read a Device ID/Vendor ID
	cmp eax, 0xFFFFFFFF		; 0xFFFFFFFF is returned for an non-existent device
	jne init_pci_probe_found	; Found a device
init_pci_probe_next:
	add edx, 0x00000100		; Skip to next PCI device
	cmp edx, 0x00FFFF00		; Maximum of 65536 devices
	jge init_pci_probe_end
	jmp init_pci_probe

init_pci_probe_found:
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
	jmp init_pci_probe_next

init_pci_probe_end:
	mov eax, 0xFFFFFFFF
	mov ecx, 4
	rep stosd

init_pci_not_found:
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
