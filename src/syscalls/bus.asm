; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; Bus Functions
; =============================================================================


; RDX format:
; 0x 00 00 SG SG BS DF RG RG
; SG = PCIe Segment Group, 16 bits (Ignored for PCI)
; BS = Bus, 8 bits
; DF = Device/Function, 8 bits (5 bit device, 3 bit function)
; RG = Register, 16 bits (Using 10 bits for PCIe and 6 bits for PCI)


; -----------------------------------------------------------------------------
; os_bus_read -- Read from a register on a bus device
;  IN:	RDX = Register to read from
; OUT:	EAX = Register value that was read
;	All other registers preserved
os_bus_read:
	cmp byte [os_BusEnabled], 2	; Check if PCIe was enabled
	jne os_bus_read_pci		; If not, fall back to PCI
os_bus_read_pcie:
	call os_pcie_read
	ret
os_bus_read_pci:
	call os_pci_read
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_bus_write -- Write to a register on a bus device
;  IN:	RDX = Register to write to
;	EAX = Register value to be written
; OUT:	Nothing, all registers preserved
os_bus_write:
	cmp byte [os_BusEnabled], 2	; Check if PCIe was enabled
	jne os_bus_write_pci		; If not, fall back to PCI
os_bus_write_pcie:
	call os_pcie_write
	ret
os_bus_write_pci:
	call os_pci_write
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
