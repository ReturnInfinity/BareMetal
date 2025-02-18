; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; xHCI (USB 3) Driver
; =============================================================================


; -----------------------------------------------------------------------------
xhci_init:
	push rdx			; RDX should already point to a supported device for os_bus_read/write

	; Gather the Base I/O Address of the device
	mov al, 0			; Read BAR0
	call os_bus_read_bar
	mov [os_xHCI_Base], rax
	mov rsi, rax			; RSI holds the base for MMIO

	; Set PCI Status/Command values
	mov dl, 0x01			; Read Status/Command
	call os_bus_read
	bts eax, 10			; Set Interrupt Disable
	bts eax, 2			; Enable Bus Master
	bts eax, 1			; Enable Memory Space
	call os_bus_write		; Write updated Status/Command

	; Check for MSI-X in PCI Capabilities
	mov dl, 1
	call os_bus_read		; Read register 1 for Status/Command
	bt eax, 20			; Check bit 4 of the Status word (31:16)
	jnc xhci_init_error		; If if doesn't exist then bail out
	mov dl, 13
	call os_bus_read		; Read register 13 for the Capabilities Pointer (7:0)
	and al, 0xFC			; Clear the bottom two bits as they are reserved
xhci_init_cap_next:
	shr al, 2			; Quick divide by 4
	mov dl, al
	call os_bus_read
	cmp al, 0x11
	je xhci_init_msix
xhci_init_cap_next_offset:
	shr eax, 8			; Shift pointer to AL
	cmp al, 0x00			; End of linked list?
	jne xhci_init_cap_next		; If not, continue reading
	jmp xhci_init_error		; Otherwise bail out
xhci_init_msix:
	push rdx
	; Enable MSI-X, Mask it, Get Table Size
	; QEMU MSI-X Entry
	; 000FA011 <- 1st Cap ID 0x11 (MSIX), next ptr 0xA0, message control 0x0F - Table size is bits 10:0 so 0x0F
	; 00003000 <- BIR (2:0) is 0x0 so BAR0, Table Offset (31:3) - 8-byte aligned so clear low 3 bits - 0x3000 in this case
	; 00003800 <- Pending Bit BIR (2:0) and Pending Bit Offset (31:3) - 0x3800 in this case
	call os_bus_read
	mov ecx, eax			; Save for Table Size
	bts eax, 31			; Enable MSIX
	bts eax, 30			; Set Function Mask
	call os_bus_write
	shr ecx, 16			; Shift Message Control to low 16-bits
	and cx, 0x7FF			; Keep bits 10:0
	; Read the BIR and Table Offset
	push rdx
	add dl, 1
	call os_bus_read
	mov ebx, eax			; EBX for the Table Offset
	and ebx, 0xFFFFFFF8		; Clear bits 2:0
	and eax, 0x00000007		; Keep bits 2:0 for the BIR
	add al, 0x04			; Add offset to start of BARs
	mov dl, al
	call os_bus_read		; Read the BAR address
	add rax, rbx			; Add offset to base
	sub rax, 0x04
	mov rdi, rax
	pop rdx
	; Configure MSI-X Table
;	push rcx
	add cx, 1			; Table Size is 0-indexed
	mov ebx, 0x000040A0		; Trigger Mode (15), Level (14), Delivery Mode (10:8), Vector (7:0)
xhci_init_msix_entry:
	mov rax, [os_LocalAPICAddress]	; 0xFEE for bits 31:20, Dest (19:12), RH (3), DM (2)
	stosd				; Store Message Address Low
	shr rax, 32			; Rotate the high bits to EAX
	stosd				; Store Message Address High
	mov eax, ebx
	inc ebx
	stosd				; Store Message Data
	xor eax, eax			; Bits 31:1 are reserved, Masked (0) - 1 for masked
	stosd				; Store Vector Control
	dec cx
	cmp cx, 0
	jne xhci_init_msix_entry
	; Create a gate in the IDT
	mov edi, 0xA0
	mov rax, xhci_int0
	call create_gate		; Create the gate for the Primary Interrupter
	mov edi, 0xA1
	mov rax, xhci_int1
	call create_gate		; Create the gate for the Primary Interrupter
	mov edi, 0xA2
	mov rax, xhci_int2
	call create_gate		; Create the gate for the Primary Interrupter

	; Mark controller memory as un-cacheable
	mov rax, [os_xHCI_Base]
	shr rax, 18
	and al, 0b11111000		; Clear the last 3 bits
	mov rdi, 0x10000		; Base of low PDE
	add rdi, rax
	mov rax, [rdi]
	btr rax, 3			; Clear PWT to disable caching
	bts rax, 4			; Set PCD to disable caching
	mov [rdi], rax

	; Gather CAPLENGTH, check HCIVERSION, get offsets
	mov [xhci_db], rsi		; Copy xHCI Base to DB, this gets incremented later
	mov [xhci_rt], rsi		; Copy xHCI Base to RT, this gets incremented later
	mov eax, [rsi+xHCI_CAPLENGTH]	; Read 4 bytes starting at CAPLENGTH
	mov [xhci_caplen], al		; Save the CAPLENGTH offset
	; Check for a valid version number
	shr eax, 16			; 16-bit version is in bits 31:16, shift to 15:0
	cmp ax, 0x0100			; Verify it is at least v1.0
	jl xhci_init_error
	mov eax, [rsi+xHCI_HCSPARAMS1]	; Gather MaxSlots (bits 7:0)
	and eax, 0x000000FF		; Keep bits 7:0
	mov byte [xhci_maxslots], al
	xor eax, eax
	mov al, [xhci_caplen]
	add rax, rsi			; RAX points to base of Host Controller Operational Registers
	mov [xhci_op], rax
	mov eax, [rsi+xHCI_HCCPARAMS1]	;
	bt eax, 2			; Context Size (CSZ)
	jnc xhci_init_32bytecsz		; If bit is clear then use 32 bytes
	mov dword [xhci_csz], 64	; Otherwise set to 64
xhci_init_32bytecsz:
	mov eax, [rsi+xHCI_DBOFF]	; Read the xHCI Doorbell Offset Register
	and eax, 0xFFFFFFFC		; Clear bits 1:0
	add [xhci_db], rax
	mov eax, [rsi+xHCI_RTSOFF]	; Read the xHCI Runtime Register Base Offset Register
	and eax, 0xFFFFFFE0		; Clear bits 4:0
	add [xhci_rt], rax
	; TODO - Read HCSPARAMS2 to get Event Ring Segment Table Max (bits 7:4)

; QEMU xHCI Extended Capabilities Entries
; 00000000febf0020: 0x02 0x04 0x00 0x02 0x55 0x53 0x42 0x20 <- USB 2
; 00000000febf0028: 0x05 0x04 0x00 0x00 0x00 0x00 0x00 0x00 <- Offset 5, Count 4
; 00000000febf0030: 0x02 0x00 0x00 0x03 0x55 0x53 0x42 0x20 <- USB 3
; 00000000febf0038: 0x01 0x04 0x00 0x00 0x00 0x00 0x00 0x00 <- Offset 1, Count 4

;	; Process xHCI Extended Capabilities Entries (16 bytes each)
;	xor ebx, ebx
;	mov ebx, [rsi+xHCI_HCCPARAMS1]	; Gather xECP (bits 31:16)
;	and ebx, 0xFFFF0000		; Keep only bits 31:16
;	shr ebx, 14			; Shift right for xECP * 4
;xhci_xecp_read:
;	mov eax, [rsi+rbx]		; Load first 4 bytes
;	cmp al, 0x01			; Legacy Entry
;	je xhci_xecp_read_legacy
;	cmp al, 0x02			; Supported Protocols
;	je xhci_xecp_read_supported_protocol
;	jmp xhci_xecp_read_next
;xhci_xecp_read_legacy:
;	; Release BIOS ownership
;	; Set bit 24 to indicate to the BIOS to release ownership
;	; The BIOS should clear bit 16 indicating it has successfully done so
;	; Ownership is released when bit 24 is set *and* bit 16 is clear
;	jmp xhci_xecp_read_next
;xhci_xecp_read_supported_protocol:
;	; Parse the supported protocol if needed
;xhci_xecp_read_next:
;	mov eax, [rsi+rbx]		; Load first 4 bytes of entry again
;	shr eax, 8			; Shift Next to AL
;	and eax, 0x000000FF		; Keep only AL
;	jz xhci_xecp_end		; If AL = 0 then we are at the end
;	shl eax, 2
;	add rbx, rax
;	jmp xhci_xecp_read
;xhci_xecp_end:

	; Reset the controller
xhci_init_halt:
	mov rsi, [xhci_op]		; xHCI Operational Registers Base
	mov eax, [rsi+xHCI_USBCMD]	; Read current Command Register value
	bt eax, 0			; Check RS (bit 0)
	jnc xhci_init_reset		; If the bit was clear, proceed to reset
	btr eax, 0			; Clear RS (bit 0)
	mov [rsi+xHCI_USBCMD], eax	; Write updated Command Register value
	mov rax, 20000			; Wait 20ms (20000µs)
	call b_delay
	mov eax, [rsi+xHCI_USBSTS]	; Read Status Register
	bt eax, 0			; Check HCHalted (bit 0) - it should be 1
	jnc xhci_init_error		; Bail out if HCHalted wasn't cleared after 20ms
xhci_init_reset:
	mov eax, [rsi+xHCI_USBCMD]	; Read current Command Register value
	bts eax, 1			; Set HCRST (bit 1)
	mov [rsi+xHCI_USBCMD], eax	; Write updated Command Register value
	mov rax, 100000			; Wait 100ms (100000µs)
	call b_delay
	mov eax, [rsi+xHCI_USBSTS]	; Read Status Register
	bt eax, 11			; Check CNR (bit 11)
	jc xhci_init_error		; Bail out if CNR wasn't cleared after 100ms
	mov eax, [rsi+xHCI_USBCMD]	; Read current Command Register value
	bt eax, 1			; Check HCRST (bit 1)
	jc xhci_init_error		; Bail out if HCRST wasn't cleared after 100ms

	; Configure the controller
	mov rax, os_usb_DCI		; Load the address of the Device Context Index
	mov [rsi+xHCI_DCBAPP], rax	; Set the Device Context Base Address Array Pointer Register
	mov rax, os_usb_CR		; Load the address of the Command Ring
	bts rax, 0			; Set RCS (bit 0)
	mov [rsi+xHCI_CRCR], rax	; Set the Command Ring Control Register
	mov eax, [rsi+xHCI_USBSTS]	; Read Status Register
	mov [rsi+xHCI_USBSTS], eax	; Write Status Register back
	xor eax, eax
	mov al, [xhci_maxslots]
	mov [rsi+xHCI_CONFIG], eax
	mov eax, 0
	mov [rsi+xHCI_DNCTRL], eax

	; Build entries in the Device Controller Index
	; TODO - Build what is needed. QEMU starts with 8
	mov rdi, os_usb_DCI
	mov rax, os_usb_scratchpad
	stosq				; Store the address of the scratchpad
	mov rcx, 8
	mov rax, os_usb_DC0		; Start of the Device Context Entries
xhci_store_DC:
	stosq
	add rax, 0x800			; 2KiB
	dec rcx
	jnz xhci_store_DC

	; Build scratchpad entries
	mov rdi, os_usb_scratchpad
	mov rax, os_usb_scratchpad
	mov rcx, 16
xhci_build_scratchpad:
	add rax, 4096
	stosq
	dec rcx
	jnz xhci_build_scratchpad

	; Build entries in the Command Ring
	; Each TRB in the Command Ring is 16 bytes
	; Build 8 entries for now. Last one is a link to the first
	; mov rdi, os_usb_CR
	; TODO Create the link TRB

	; Configure Segment Table
	; ┌──────────────────────────────────────┐
	; | 31             16 15        6 5     0|
	; ├──────────────────────────────┬───────┤
	; | Ring Segment Base Address Lo | RsvdZ |
	; ├──────────────────────────────┴───────┤
	; |     Ring Segment Base Address Hi     |
	; ├──────────────────┬───────────────────┤
	; |      RsvdZ       | Ring Segment Size | 
	; ├──────────────────┴───────────────────┤
	; |                RsvdZ                 |
	; └──────────────────────────────────────┘
	; Segment table for Interrupter 0
	mov rax, os_usb_ERS+0		; Starting Address of Event Ring Segment
	mov rdi, os_usb_ERST+0		; Starting Address of Event Ring Segment Table
	mov [rdi], rax			; Ring Segment Base Address
	mov eax, 16
	mov [rdi+8], eax		; Ring Segment Size (bits 15:0)
	xor eax, eax
	mov [rdi+12], eax
	; Segment table for Interrupter 1
	mov rax, os_usb_ERS+4096	; Starting Address of Event Ring Segment
	mov rdi, os_usb_ERST+4096	; Starting Address of Event Ring Segment Table
	mov [rdi], rax			; Ring Segment Base Address
	mov eax, 16
	mov [rdi+8], eax		; Ring Segment Size (bits 15:0)
	xor eax, eax
	mov [rdi+12], eax
	; Segment table for Interrupter 2
	mov rax, os_usb_ERS+8192	; Starting Address of Event Ring Segment
	mov rdi, os_usb_ERST+8192	; Starting Address of Event Ring Segment Table
	mov [rdi], rax			; Ring Segment Base Address
	mov eax, 16
	mov [rdi+8], eax		; Ring Segment Size (bits 15:0)
	xor eax, eax
	mov [rdi+12], eax

	; Configure Event Ring for Primary Interrupter (Interrupt 0)
	mov rdi, [xhci_rt]
	add rdi, xHCI_IR_0		; Interrupt Register 0
; DEBUG - Disable int 0 for now - Interrupts don't fire until kernel is fully started
;	mov eax, 2			; Interrupt Enable (bit 1), Interrupt Pending (bit 0)
	xor eax, eax
	mov [rdi+0x00], eax		; Interrupter Management (IMAN)
	mov eax, 64
	mov [rdi+0x04], eax		; Interrupter Moderation (IMOD)
	mov eax, 1			; ERSTBA points to 1 Segment Table
	mov [rdi+0x08], eax		; Event Ring Segment Table Size (ERSTSZ)
	add rax, os_usb_ERS
	mov [rdi+0x18], rax		; Event Ring Dequeue Pointer (ERDP)
	mov rax, os_usb_ERST
	mov [rdi+0x10], rax		; Event Ring Segment Table Base Address (ERSTBA)

	; Configure Event Ring for Interrupter 1
	mov rdi, [xhci_rt]
	add rdi, xHCI_IR_1		; Interrupt Register 1
	mov eax, 2			; Interrupt Enable (bit 1), Interrupt Pending (bit 0)
	mov [rdi+0x00], eax		; Interrupter Management (IMAN)
	mov eax, 64
	mov [rdi+0x04], eax		; Interrupter Moderation (IMOD)
	mov eax, 1			; ERSTBA points to 1 Segment Table
	mov [rdi+0x08], eax		; Event Ring Segment Table Size (ERSTSZ)
	add rax, os_usb_ERS+4096
	mov [rdi+0x18], rax		; Event Ring Dequeue Pointer (ERDP)
	mov rax, os_usb_ERST+4096
	mov [rdi+0x10], rax		; Event Ring Segment Table Base Address (ERSTBA)

	; Configure Event Ring for Interrupter 2
	mov rdi, [xhci_rt]
	add rdi, xHCI_IR_2		; Interrupt Register 2
	mov eax, 2			; Interrupt Enable (bit 1), Interrupt Pending (bit 0)
	mov [rdi+0x00], eax		; Interrupter Management (IMAN)
	mov eax, 64
	mov [rdi+0x04], eax		; Interrupter Moderation (IMOD)
	mov eax, 1			; ERSTBA points to 1 Segment Table
	mov [rdi+0x08], eax		; Event Ring Segment Table Size (ERSTSZ)
	add rax, os_usb_ERS+8192
	mov [rdi+0x18], rax		; Event Ring Dequeue Pointer (ERDP)
	mov rax, os_usb_ERST+8192
	mov [rdi+0x10], rax		; Event Ring Segment Table Base Address (ERSTBA)

	; Start Controller
	mov eax, 0x05			; Set bit 0 (RS) and bit 2 (INTE)
	mov [rsi+xHCI_USBCMD], eax

	; Check the available ports and reset them
	xor ecx, ecx			; Slot counter
	xor edx, edx			; Max slots
	mov dl, byte [xhci_maxslots]
xhci_check_next:
	mov ebx, 0x400			; Offset to start of Port Registers
	shl ecx, 4			; Quick multiply by 16
	add ebx, ecx			; Add offset to EBX
	shr ecx, 4			; Quick divide by 16
	mov eax, [rsi+rbx]		; Load PORTSC
	bt eax, 0			; Current Connect Status
	jnc xhci_reset_skip
	bts eax, 4			; Port Reset
	mov [rsi+rbx], eax

	; TODO - insert Enable Slot, Set Address, and others here
xhci_reset_skip:
	inc ecx
	cmp ecx, edx
	jne xhci_check_next

	; Check Event ring for xHCI_ETRB_PSC
	mov rsi, os_usb_ERS
	mov eax, [rsi+12]		; Load dword 3
	shr eax, 10			; Shift Type to AL
	cmp al, xHCI_ETRB_PSC
	je xhci_enable_slot
xhci_enable_slot:

	; Build a TRB for Enable Slot in the Command Ring
	mov rdi, os_usb_CR
	xor eax, eax
	stosd				; Store dword 0
	stosd				; Store dword 1
	stosd				; Store dword 2
	mov al, xHCI_CTRB_ESLOT		; Enable Slot opcode
	shl eax, 10			; Shift opcode to bits 15:10
	bts eax, 0			; Cycle Bit
	stosd				; Store dword 3

	; Ring the Doorbell for the Command Ring
	xor eax, eax
	mov rdi, [xhci_db]
	stosd				; Write to the Doorbell Register

	; Slot Enable Command Event TRB
	; ┌──────────────────────────────────────┐
	; | 31    24 23        15      10 9   1 0|
	; ├──────────────────────────────────────┤
	; |     Address of Enable Slot TRB Lo    |
	; ├──────────────────────────────────────┤
	; |     Address of Enable Slot TRB Hi    |
	; ├─────────┬────────────────────────────┤
	; |CompCode |          RsvdZ             | 
	; ├─────────┴────────────┬───────┬─────┬─┤
	; | Slot ID |    RsvdZ   |   33  |RsvdZ|C|
	; └─────────┴────────────┴───────┴─────┴─┘

	; TODO - Check Event ring for the Completion Code of the TRB that was sent
	; Look for the Address of the TRB

	mov eax, 100000
	call b_delay

	; Build the Input Context (6.2.5)
	; Each section of the Input Context is either 32 or 64-bytes in length (depending on HCPARAMS1.CSZ)
	; Entries are as follows:
	;
	; Input Control Context (6.2.5.1)
	; Slot Context
	; Endpoint Context 0
	; Endpoint Context 1 OUT
	; Endpoint Context 1 IN
	; ...
	; Endpoint Context 15 OUT
	; Endpoint Context 15 IN
	;
	mov rdi, os_usb_IDC
	; Set Input Control Context
	mov dword [rdi+0], 0x00000000
	mov dword [rdi+4], 0x00000003	; Set A01 and A00 as we want Endpoint Context 0 and Slot Context, respectively
	; Set Slot Context
	mov eax, [xhci_csz]
	add rdi, rax
	mov dword [rdi+0], 0x08300000	; Set Context Entries (31:27) to 1, set Speed (23:20)
	mov dword [rdi+4], 0x00050000	; Set Root Hub Port Number (23:16)
	mov dword [rdi+8], 0x00000000	; Set Interrupter Target (31:22)
	; TODO - Values above should not be hard-coded
	; Set Endpoint Context 0
	mov eax, [xhci_csz]
	add rdi, rax
	mov dword [rdi+0], 0x00000000
	mov dword [rdi+4], 0x00080026	; Set Max Packet Size (31:16) to 8, EP Type (5:3) to 4 (Control), CErr (2:1) to 3
	mov rax, os_usb_TR0		; Address of Transfer Ring
	bts rax, 0			; DCS
	mov qword [rdi+8], rax
	mov dword [rdi+16], 0x00000008	; Set Average TRB Length (15:0)

	; Build a TRB for Set Address in the Command Ring
	mov rdi, os_usb_CR
	add rdi, 16
	mov rax, os_usb_IDC		; Address of the Input Context
	stosq				; dword 0 & 1
	xor eax, eax			; Reserved
	stosd				; dword 2
	mov eax, 0x01000000		; Set Slot ID (31:24)
	mov al, xHCI_CTRB_ADDRD
	shl ax, 10
;	bts eax, 9			; B
	bts eax, 0			; Cycle
	stosd				; dword 3

	xor eax, eax
	mov rdi, [xhci_db]
	stosd				; Write to the Doorbell Register

	; Set Address Command Event TRB
	; ┌──────────────────────────────────────┐
	; | 31    24 23        15      10 9   1 0|
	; ├──────────────────────────────────────┤
	; |      Address of Input Context Lo     |
	; ├──────────────────────────────────────┤
	; |      Address of Input Context Hi     |
	; ├─────────┬────────────────────────────┤
	; |CompCode |          RsvdZ             | 
	; ├─────────┴────────────┬───────┬─────┬─┤
	; | Slot ID |    RsvdZ   |   33  |RsvdZ|C|
	; └─────────┴────────────┴───────┴─────┴─┘

	; TODO - Check Event ring for the Completion Code of the TRB that was sent
	; Look for the Address of the TRB

	mov eax, 100000
	call b_delay

	; Add TRBs to Transfer ring
	mov rdi, os_usb_TR0

	; Request 8 bytes from Device Descriptor to get the length

	; Setup Stage
	mov rax, 0x01000680		; 0x01 Device Descriptor
	stosd				; dword 0 - wValue (31:16), bRequest (15:8), bmRequestType (7:0)
	mov eax, 0x00080000		; Request 8 bytes
	stosd				; dword 1 - wLength (31:16), wIndex (15:0)
	mov eax, 0x00000008
	stosd				; dword 2 - Interrupter Target (31:22), TRB Transfer Length (16:0)
	mov eax, 0x00030841		; TRT 3, TRB Type 2, IDT, C
	stosd				; dword 3 - TRT (17:16), TRB Type (15:10), IDT (6), IOC (5), C (0)
	; Data Stage
	mov rax, os_usb_data0
	stosq				; dword 0 & 1 - Data Buffer (63:0)
	mov eax, 0x00000008		; Request 8 bytes
	stosd				; dword 2 - Interrupter Target (31:22), TD Size (21:17), TRB Transfer Length (16:0)
	mov eax, 0x00010C01		; DIR, TRB Type 3, C
	stosd				; dword 3 - DIR (16), TRB Type (15:10), IDT (6), IOC (5), CH (4), NS (3), ISP (2), ENT (1), C (0)
	; Status Stage
	xor eax, eax
	stosq				; dword 0 & 1 - Reserved Zero
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001013		; TRB Type 4, CH, ENT, C
	stosd				; dword 3 - DIR (16), TRB Type (15:10), IOC (5), CH (4), ENT (1), C (0)
	; Event Data
	mov rax, os_usb_data1
	stosq				; dword 0 & 1 - Data Buffer (63:0)
	xor eax, eax
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001C21		; TRB Type 7, IOC, C
	stosd				; dword 3 - TRB Type (15:10), IOC (5), Cycle (0)

	; Ring doorbell for Slot 1
	mov eax, 1
	push rdi
	mov rdi, [xhci_db]
	add rdi, 4
	stosd				; Write to the Doorbell Register
	pop rdi

	mov eax, 100000
	call b_delay

	; Request full data from Device Descriptor

	xor ebx, ebx
	mov bl, [os_usb_data0]		; BL contains length

	; Setup Stage
	mov rax, 0x01000680		; 0x01 Device Descriptor
	stosd				; dword 0 - wValue (31:16), bRequest (15:8), bmRequestType (7:0)
	mov eax, ebx			; BL contains length
	shl eax, 16
	stosd				; dword 1 - wLength (31:16), wIndex (15:0)
	mov eax, 0x00000008
	stosd				; dword 2 - Interrupter Target (31:22), TRB Transfer Length (16:0)
	mov eax, 0x00030841		; TRT 3, TRB Type 2, IDT, C
	stosd				; dword 3 - TRT (17:16), TRB Type (15:10), IDT (6), IOC (5), C (0)
	; Data Stage
	mov rax, os_usb_data0
	stosq				; dword 0 & 1 - Data Buffer (63:0)
	mov eax, ebx			; BL contains length
	stosd				; dword 2 - Interrupter Target (31:22), TD Size (21:17), TRB Transfer Length (16:0)
	mov eax, 0x00010C01		; DIR, TRB Type 3, C
	stosd				; dword 3 - DIR (16), TRB Type (15:10), IDT (6), IOC (5), CH (4), NS (3), ISP (2), ENT (1), C (0)
	; Status Stage
	xor eax, eax
	stosq				; dword 0 & 1 - Reserved Zero
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001013		; TRB Type 4, CH, ENT, C
	stosd				; dword 3 - DIR (16), TRB Type (15:10), IOC (5), CH (4), ENT (1), C (0)
	; Event Data
	mov rax, os_usb_data1
	add rax, 0x40
	stosq				; dword 0 & 1 - Data Buffer (63:0)
	xor eax, eax			; Interrupter 0 (31:22)
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001C21		; TRB Type 7, IOC, C
	stosd				; dword 3 - TRB Type (15:10), IOC (5), Cycle (0)

	; Ring doorbell for Slot 1
	mov eax, 1
	push rdi
	mov rdi, [xhci_db]
	add rdi, 4
	stosd				; Write to the Doorbell Register
	pop rdi

	; TODO - Check Device Descriptor
	; Example from QEMU mouse
	;
	; 0000: 0x12 0x01 0x00 0x02 0x00 0x00 0x00 0x40
	; 0008: 0x27 0x06 0x01 0x00 0x00 0x00 0x01 0x02
	; 0010: 0x09 0x01
	;
	; Gather Vendor ID (offset 8) and Product ID (offset 10)
	; Build a table
	; Slot / Vendor / Product / Class / Protocol

	mov eax, 100000
	call b_delay

	; Request 9 bytes from Configuration Descriptor

	; Setup Stage
	mov rax, 0x02000680		; 0x02 Configuration Descriptor
	stosd				; dword 0 - wValue (31:16), bRequest (15:8), bmRequestType (7:0)
	mov eax, 0x00090000
	stosd				; dword 1 - wLength (31:16), wIndex (15:0)
	mov eax, 0x00000008
	stosd				; dword 2 - Interrupter Target (31:22), TRB Transfer Length (16:0)
	mov eax, 0x00030841		; TRT 3, TRB Type 2, IDT, C
	stosd				; dword 3 - TRT (17:16), TRB Type (15:10), IDT (6), IOC (5), C (0)
	; Data Stage
	mov rax, os_usb_data0
	add rax, 0x20
	stosq				; dword 0 & 1 - Data Buffer (63:0)
	mov eax, 0x00000009
	stosd				; dword 2 - Interrupter Target (31:22), TD Size (21:17), TRB Transfer Length (16:0)
	mov eax, 0x00010C13		; DIR, TRB Type 3, CH, ENT, C
	stosd				; dword 3 - DIR (16), TRB Type (15:10), IDT (6), IOC (5), CH (4), NS (3), ISP (2), ENT (1), C (0)
	; Status Stage
	xor eax, eax
	stosq				; dword 0 & 1 - Reserved Zero
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001013		; TRB Type 4, CH, ENT, C
	stosd				; dword 3 - DIR (16), TRB Type (15:10), IOC (5), CH (4), ENT (1), C (0)
	; Event Data
	mov rax, os_usb_data1
	add rax, 0x40
	stosq				; dword 0 & 1 - Data Buffer (63:0)
	xor eax, eax			; Interrupter 0 (31:22)
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001C21		; TRB Type 7, IOC, C
	stosd				; dword 3 - TRB Type (15:10), IOC (5), Cycle (0)

	; Ring doorbell for Slot 1
	mov eax, 1
	push rdi
	mov rdi, [xhci_db]
	add rdi, 4
	stosd				; Write to the Doorbell Register
	pop rdi

	mov eax, 100000
	call b_delay

	; Check TotalLength
	xor ebx, ebx
	mov bx, [os_usb_data0+0x20+2]	; BX contains length

	; Request full data from Configuration Descriptor (includes Interface Descriptor (0x04) / HID Descriptor (0x21))

	; Setup Stage
	mov rax, 0x02000680		; 0x02 Configuration Descriptor
	stosd				; dword 0 - wValue (31:16), bRequest (15:8), bmRequestType (7:0)
	mov eax, ebx			; BL contains length
	shl eax, 16
	stosd				; dword 1 - wLength (31:16), wIndex (15:0)
	mov eax, 0x00000008
	stosd				; dword 2 - Interrupter Target (31:22), TRB Transfer Length (16:0)
	mov eax, 0x00030841		; TRT 3, TRB Type 2, IDT, C
	stosd				; dword 3 - TRT (17:16), TRB Type (15:10), IDT (6), IOC (5), C (0)
	; Data Stage
	mov rax, os_usb_data0
	add rax, 0x20
	stosq				; dword 0 & 1 - Data Buffer (63:0)
	mov eax, ebx			; BL contains length
	stosd				; dword 2 - Interrupter Target (31:22), TD Size (21:17), TRB Transfer Length (16:0)
	mov eax, 0x00010C13		; DIR, TRB Type 3, CH, ENT, C
	stosd				; dword 3 - DIR (16), TRB Type (15:10), IDT (6), IOC (5), CH (4), NS (3), ISP (2), ENT (1), C (0)
	; Status Stage
	xor eax, eax
	stosq				; dword 0 & 1 - Reserved Zero
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001013		; TRB Type 4, CH, ENT, C
	stosd				; dword 3 - DIR (16), TRB Type (15:10), IOC (5), CH (4), ENT (1), C (0)
	; Event Data
	mov rax, os_usb_data1
	add rax, 0x40
	stosq				; dword 0 & 1 - Data Buffer (63:0)
	xor eax, eax			; Interrupter 0 (31:22)
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001C21		; TRB Type 7, IOC, C
	stosd				; dword 3 - TRB Type (15:10), IOC (5), Cycle (0)

	; Ring doorbell for Slot 1
	mov eax, 1
	push rdi
	mov rdi, [xhci_db]
	add rdi, 4
	stosd				; Write to the Doorbell Register
	pop rdi

	; TODO - Check Configuration Descriptor
	; Example from QEMU mouse
	;
	; 0000: 0x09 0x02 0x22 0x00 0x01 0x01 0x06 0xa0
	; 0008: 0x32 0x09 0x04 0x00 0x00 0x01 0x03 0x01
	; 0010: 0x02 0x00 0x09 0x21 0x01 0x00 0x00 0x01
	; 0018: 0x22 0x34 0x00 0x07 0x05 0x81 0x03 0x04
	; 0020: 0x00 0x07
	;
	; Expanded out:
	; Configuration Descriptor
	; 0000: 0x09 0x02 0x22 0x00 0x01 0x01 0x06 0xa0
	; 0008: 0x32
	; Interface Descriptor
	; 0008:      0x09 0x04 0x00 0x00 0x01 0x03 0x01
	; 0010: 0x02 0x00
	; HID Descriptor
	; 0010:           0x09 0x21 0x01 0x00 0x00 0x01
	; 0018: 0x22 0x34 0x00
	; Endpoint Descriptor
	; 0018:                0x07 0x05 0x81 0x03 0x04
	; 0020: 0x00 0x07
	;
	; Check Number of Interfaces (offset 4) - A HID should have 0x01
	; Step though Configuration Descriptor (0x2) looking for the Interface Descriptor (0x4)
	; Check Interface Number (offset 2)
	; Check Number of Endpoints (offset 4) - Should be 0x01
	; Check Class Code (offset 5) - 0x03 = HID
	; Check Protocol (offset 7) - 0x1 = Keyboard, 0x2 = Mouse
	; Look for Endpoint Descriptor (0x5)
	; Check Endpoint Address (offset 2) - Bit 7 defines In(1)/Out(0). Bits 3:0 is Endpoint number
	; Check Attribute (offset 3) - Should be 0x03 for Interrupt
	; Check MaxPacketSize (offset 4) - 0x0008 = keyboard (ideally), 0x0004 = mouse (ideally)

	; TODO - Send Set_Idle
	; 0x00000000000A21

	mov eax, 100000
	call b_delay

	; Build a TRB for Evaluate Context in the Command Ring
	mov rdi, os_usb_CR
	add rdi, 32
	mov rax, os_usb_IDC		; Address of the Input Context
	stosq				; dword 0 & 1
	xor eax, eax
	stosd				; dword 2
	mov eax, 0x01000000		; Set Slot ID (31:24)
	mov al, xHCI_CTRB_EVALC
	shl ax, 10
	bts eax, 0			; Cycle
	stosd				; dword 3

	xor eax, eax
	mov rdi, [xhci_db]
	stosd				; Write to the Doorbell Register

	; TODO - Read the event code to verify success

	mov eax, 100000
	call b_delay

	; Update Input Context
	mov rdi, os_usb_IDC
	; Set Control Context
	mov dword [rdi+4], 0x00000009
	; Set Slot Context
	mov eax, [xhci_csz]
	add rdi, rax
	mov dword [rdi+0], 0xF8300000	; Set Context Entries (31:27) to 1, set Speed (23:20)
	; TODO - Value above should not be hard-coded
	; 0xF8 for all entries
	mov dword [rdi+4], 0x00050000	; Set Root Hub Port Number (23:16)
	; TODO - Value above should not be hard-coded
	mov dword [rdi+8], 0x00400000	; Set Interrupter Target to 1 (31:22)
	; Set Endpoint Context 0
	mov eax, [xhci_csz]
	add rdi, rax
	mov dword [rdi+0], 0x00000000
	mov dword [rdi+4], 0x00080026	; Set Max Packet Size (31:16) to 8, EP Type (5:3) to 4 (Control), CErr (2:1) to 3
	; TODO - Value above should not be hard-coded
	; Needs to be based on MaxPacketSize in the Configuration Descriptor
	mov rax, os_usb_TR0		; Address of Transfer Ring
	bts rax, 0			; DCS
	mov qword [rdi+8], rax
	mov dword [rdi+16], 0x00000008	; Set Average TRB Length (15:0) to 8
	; Set Endpoint Context 1 IN
	mov eax, [xhci_csz]
	add rdi, rax
	add rdi, rax
	mov dword [rdi+0], 0x00060000	; Set Interval (23:16) to 6
	mov dword [rdi+4], 0x0008003e	; Set Max Packet Size (31:16) to 8, EP Type (5:3) to 7 (Interrupt IN), CErr (2:1) to 3
	mov rax, os_usb_TR0		; Address of Transfer Ring
	add rax, 0x200
	bts rax, 0
	mov qword [rdi+8], rax
	mov dword [rdi+16], 0x00080008	; Set Max ESIT Payload (31:16) to 8, Average TRB Length (15:0) to 8

	; Build a TRB for Configure Endpoint in the Command Ring
	mov rdi, os_usb_CR
	add rdi, 48
	mov rax, os_usb_IDC		; Address of the Input Context
	stosq				; dword 0 & 1
	xor eax, eax
	stosd				; dword 2
	mov eax, 0x01000000		; Set Slot ID (31:24)
	mov al, xHCI_CTRB_CONFE
	shl ax, 10
	bts eax, 0			; Cycle
	stosd				; dword 3

	xor eax, eax
	mov rdi, [xhci_db]
	stosd				; Write to the Doorbell Register

	; Prepare to read a packet
	mov rdi, os_usb_TR0
	add rdi, 0x200
	; Normal
	mov rax, os_usb_data0
	add rax, 0x100
	stosq				; dword 0 & 1 - Data Buffer Pointer (63:0)
	mov eax, 0x00000008
	stosd				; dword 2 - Interrupter Target (31:22), TD Size (21:17), TRB Transfer Length (16:0)
	mov eax, 0x00000413		; TRB Type 1, CH, ENT, C
	stosd				; dword 3 - TRB Type (15:10), CH (4), ENT (1), Cycle (0)
	; Event Data
	mov rax, os_usb_data0
	add rax, 0x120
	stosq				; dword 0 & 1 - Data Buffer Pointer (63:0)
	mov eax, 0x00400000		; Interrupter Target 1
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001C21		; TRB Type 7, IOC, C
	stosd				; dword 3 - TRB Type (15:10), IOC (5), Cycle (0)

	; Ring doorbell for Slot 1
	mov eax, 3			; epid 3
	push rdi
	mov rdi, [xhci_db]
	add rdi, 4
	stosd				; Write to the Doorbell Register
	pop rdi

	jmp xhci_init_done

xhci_init_error:
	jmp $

xhci_init_done:
	; Unmask MSI-X
	pop rdx
	call os_bus_read
	btr eax, 30			; Clear Function Mask
	call os_bus_write

	pop rdx
	ret

xhci_caplen:	db 0
xhci_maxslots:	db 0
xhci_op:	dq 0			; Start of Operational Registers
xhci_db:	dq 0			; Start of Doorbell Registers
xhci_rt:	dq 0			; Start of Runtime Registers
xhci_csz:	dd 32			; Default Context Size
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; xHCI Interrupter 0 - Controller
align 8
xhci_int0:
	push rsi
	push rax

	mov al, 0x00
	call os_debug_dump_al

	; Increment counter
	add dword [os_xhci_int0_count], 1

	; Clear Controller Interrupt Pending
	mov rdi, [xhci_op]
	add rdi, xHCI_USBSTS
	mov eax, [rdi]
	btr eax, 3			; Clear Event Interrupt (EINT) (bit 3)
	mov [rdi], eax

	; Clear Interrupter 0 Pending
	mov rdi, [xhci_rt]
	add rdi, xHCI_IR_0		; Interrupt Register 0
	mov eax, [rdi+xHCI_IR_IMAN]
;	btr eax, 0			; Clear Interrupt Pending (IP) (bit 0)
	mov [rdi+xHCI_IR_IMAN], eax

	; Increment dequeue
	mov eax, [rdi+xHCI_IR_ERDP]
	add eax, 16
	mov [rdi+xHCI_IR_ERDP], eax

	; Acknowledge the interrupt
	mov ecx, APIC_EOI
	xor eax, eax
	call os_apic_write

	pop rax
	pop rdi
	iretq
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; xHCI Interrupter 1 - Keyboard
align 8
xhci_int1:
	push rdi
	push rax

	; Clear Controller Interrupt Pending
	mov rdi, [xhci_op]
	add rdi, xHCI_USBSTS
	mov eax, [rdi]
	btr eax, 3			; Clear Event Interrupt (EINT) (bit 3)
	mov [rdi], eax

	; Get key press
	; TODO Logic for shift press
	mov eax, [os_usb_data0+0x100]
	shr eax, 16
	and eax, 0xFF			; Keep AL only
	mov rdi, usbkeylayoutlower
	add rdi, rax
	mov byte al, [rdi]
	mov [key], al
	
	; Add TRBs for next interrupt
	mov rdi, os_usb_TR0
	add rdi, 0x200
	add rdi, [tval]
	; Normal
	mov rax, os_usb_data0
	add rax, 0x100
	stosq				; dword 0 & 1 - Data Buffer Pointer (63:0)
	mov eax, 0x00000008
	stosd				; dword 2 - Interrupter Target (31:22), TD Size (21:17), TRB Transfer Length (16:0)
	mov eax, 0x00000413		; TRB Type 1, CH, ENT, C
	stosd				; dword 3 - TRB Type (15:10), CH (4), ENT (1), Cycle (0)
	; Event Data
	mov rax, os_usb_data0
	add rax, 0x120
	stosq				; dword 0 & 1 - Data Buffer Pointer (63:0)
	mov eax, 0x00400000		; Interrupter Target 1
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001C21		; TRB Type 7, IOC, C
	stosd				; dword 3 - TRB Type (15:10), IOC (5), Cycle (0)

	; Clear Interrupter 1 Pending (if set)
	mov rdi, [xhci_rt]
	add rdi, xHCI_IR_1		; Interrupt Register 1
	mov eax, [rdi]
	btr eax, 0			; Clear Interrupt Pending (IP) (bit 0)
	mov [rdi], eax

	; Increment Interrupter Event Ring Dequeue Pointer
	mov rax, [rdi+xHCI_IR_ERDP]
	add rax, 16
	mov [rdi+xHCI_IR_ERDP], rax
	
	add qword [tval], 32

	; Ring doorbell for Slot 1
	mov eax, 3			; epid 3
	push rdi
	mov rdi, [xhci_db]
	add rdi, 4
	stosd				; Write to the Doorbell Register
	pop rdi

	; Acknowledge the interrupt
	mov ecx, APIC_EOI
	xor eax, eax
	call os_apic_write

	pop rax
	pop rdi
	iretq
; -----------------------------------------------------------------------------
tval: dq 32

; -----------------------------------------------------------------------------
; xHCI Interrupter 2 - Mouse
align 8
xhci_int2:
	push rsi
	push rax

	mov al, 0x02
	call os_debug_dump_al

	; Clear Controller Interrupt Pending
	mov rdi, [xhci_op]
	add rdi, xHCI_USBSTS
	mov eax, [rdi]
	btr eax, 3			; Clear Event Interrupt (EINT) (bit 3)
	mov [rdi], eax

	; Clear Interrupter 2 Pending
	mov rdi, [xhci_rt]
	add rdi, xHCI_IR_2		; Interrupt Register 2
	mov eax, [rdi]
	btr eax, 0			; Clear Interrupt Pending (IP) (bit 0)
	mov [rdi], eax

	; Acknowledge the interrupt
	mov ecx, APIC_EOI
	xor eax, eax
	call os_apic_write

	pop rax
	pop rdi
	iretq
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; xHCI Interrupter Stub
align 8
xhci_int_stub:
	; Acknowledge the interrupt
	mov ecx, APIC_EOI
	xor eax, eax
	call os_apic_write

	iretq
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; xHCI Mouse Interrupter
align 8
xhci_int_mouse:
	; Acknowledge the interrupt
	mov ecx, APIC_EOI
	xor eax, eax
	call os_apic_write

	iretq
; -----------------------------------------------------------------------------



; Memory (to be redone)
os_usb:			equ 0x0000000000680000	; 0x680000 -> 0x69FFFF	128K USB Structures
os_usb_DCI:		equ 0x0000000000680000	; 0x680000 -> 0x6807FF	2K Device Context Index
os_usb_DC0:		equ 0x0000000000680800	; 2K Device Context 0
os_usb_DC1:		equ 0x0000000000681000	; 2K Device Context 1
os_usb_DC2:		equ 0x0000000000681800	; 2K Device Context 2
os_usb_DC3:		equ 0x0000000000682000	; 2K Device Context 3
os_usb_DC4:		equ 0x0000000000682800	; 2K Device Context 4
os_usb_DC5:		equ 0x0000000000683000	; 2K Device Context 5
os_usb_DC6:		equ 0x0000000000683800	; 2K Device Context 6
os_usb_DC7:		equ 0x0000000000684000	; 2K Device Context 7

os_usb_CR:		equ 0x0000000000690000	; 0x690000 -> 0x69FFFF	64K Command Ring (16-bytes per entry. 4K in future)
os_usb_ERST:		equ 0x00000000006A0000	; 0x6A0000 -> 0x6AFFFF	64K Event Ring Segment Table
os_usb_ERS:		equ 0x00000000006B0000	; 0x6B0000 -> 0x6BFFFF	64K Event Ring Segment
os_usb_IDC:		equ 0x00000000006C0000	; Input device context (temporary buffer of max 64+2048 bytes)
os_usb_TR0:		equ 0x00000000006D0000	; Temp transfer ring
os_usb_data0:		equ 0x00000000006E0000
os_usb_data1:		equ 0x00000000006F0000

os_usb_scratchpad:	equ 0x0000000000700000

; Register list

; Host Controller Capability Registers (Read-Only)
xHCI_CAPLENGTH	equ 0x00	; 1-byte Capability Registers Length
xHCI_HCIVERSION	equ 0x02	; 2-byte Host Controller Interface Version Number
xHCI_HCSPARAMS1	equ 0x04	; 4-byte Structural Parameters 1
xHCI_HCSPARAMS2	equ 0x08	; 4-byte Structural Parameters 2
xHCI_HCSPARAMS3	equ 0x0C	; 4-byte Structural Parameters 3
xHCI_HCCPARAMS1	equ 0x10	; 4-byte Capability Parameters 1
xHCI_DBOFF	equ 0x14	; 4-byte Doorbell Offset
xHCI_RTSOFF	equ 0x18	; 4-byte Runtime Registers Space Offset
xHCI_HCCPARMS2	equ 0x1C	; 4-byte Capability Parameters 2 (xHCI v1.1+)
xHCI_VTIOSOFF	equ 0x20	; 4-byte VTIO Register Space Offset (xHCI v1.2+)

; Host Controller Operational Registers (Starts at xHCI_Base + CAPLENGTH)
xHCI_USBCMD	equ 0x00	; 4-byte USB Command Register
xHCI_USBSTS	equ 0x04	; 4-byte USB Status Register
xHCI_PAGESIZE	equ 0x08	; 4-byte Page Size Register (Read-Only)
xHCI_DNCTRL	equ 0x14	; 4-byte Device Notification Control Register
xHCI_CRCR	equ 0x18	; 8-byte Command Ring Control Register
xHCI_DCBAPP	equ 0x30	; 8-byte Device Context Base Address Array Pointer Register
xHCI_CONFIG	equ 0x38	; 4-byte Configure Register

; Host Controller USB Port Register Set (Starts at xHCI_Base + CAPLENGTH + 0x0400 - 16 bytes per port)
xHCI_PORTSC	equ 0x00	; 4-byte Port Status and Control Register
xHCI_PORTPMSC	equ 0x04	; 4-byte Port PM Status and Control Register
xHCI_PORTLI	equ 0x08	; 4-byte Port Link Info Register (Read-Only)
xHCI_PORTHLPMC	equ 0x0C	; 4-byte Port Hardware LPM Control Register

; Host Controller Doorbell Register Set (Starts at xHCI_Base + DBOFF)
xHCI_CDR	equ 0x00	; 4-byte Command Doorbell Register (Target bits 7:0)
xHCI_DS1	equ 0x04	; 4-byte Device Slot #1 Doorbell
xHCI_DS2	equ 0x08	; 4-byte Device Slot #2 Doorbell

; Host Controller Runtime Register Set (Starts at xHCI_Base + RTSOFF)
xHCI_MICROFRAME	equ 0x00	; 4-byte Microframe Index Register
; Microframe is incremented every 125 microseconds. Each frame (1ms) is 8 microframes
; 28-bytes padding
xHCI_IR_0	equ 0x20	; 32-byte Interrupter Register Set 0
xHCI_IR_1	equ 0x40	; 32-byte Interrupter Register Set 1
xHCI_IR_2	equ 0x60	; 32-byte Interrupter Register Set 2

; Interrupter Register Set
xHCI_IR_IMAN	equ 0x00	; 4-byte Interrupter Management
xHCI_IR_IMOD	equ 0x04	; 4-byte Interrupter Moderation
xHCI_IR_ERSTSZ	equ 0x08	; 4-byte Event Ring Segment Table Size
; 4-byte padding
xHCI_IR_ERSTBA	equ 0x10	; 8-byte Event Ring Segment Table Base Address
xHCI_IR_ERDP	equ 0x18	; 8-byte Event Ring Dequeue Pointer

; Transfer TRB List
xHCI_TTRB_NORM	equ 1		; Normal
xHCI_TTRB_SETUP	equ 2		; Setup Stage
xHCI_TTRB_DATA	equ 3		; Data Stage
xHCI_TTRB_STS	equ 4		; Status Stage
xHCI_TTRB_ISOC	equ 5		; Isoch
xHCI_TTRB_LINK	equ 6		; Link
xHCI_TTRB_EDATA	equ 7		; Event Data
xHCI_TTRB_NOOP	equ 8		; No-Op

; Command TRB List
xHCI_CTRB_LINK	equ 6		; Link
xHCI_CTRB_ESLOT	equ 9		; Enable Slot
xHCI_CTRB_DSLOT	equ 10		; Disable Slot
xHCI_CTRB_ADDRD	equ 11		; Address Device
xHCI_CTRB_CONFE	equ 12		; Configure Endpoint
xHCI_CTRB_EVALC	equ 13		; Evaluate Context
xHCI_CTRB_RESE	equ 14		; Reset Endpoint
xHCI_CTRB_STPE	equ 15		; Stop Endpoint
xHCI_CTRB_SETTR	equ 16		; Set TR Dequeue Pointer
xHCI_CTRB_RESD	equ 17		; Reset Device
xHCI_CTRB_NOOP	equ 23		; No-Op

; Event TRB List
xHCI_ETRB_TE	equ 32		; Transfer Event
xHCI_ETRB_CC	equ 33		; Command Completion Event
xHCI_ETRB_PSC	equ 34		; Port Status Change

; Standard Request Codes
xHCI_GET_STATUS		equ 0x00
xHCI_CLEAR_FEATURE	equ 0x01
xHCI_SET_FEATURE	equ 0x03
xHCI_GET_DESCRIPTOR	equ 0x06
xHCI_SET_DESCRIPTOR	equ 0x07

; Completion Codes
xHCI_CC_INVALID				equ 0
xHCI_CC_SUCCESS				equ 1
xHCI_CC_DATA_BUFFER_ERROR		equ 2
xHCI_CC_BABBLE_DETECTED			equ 3
xHCI_CC_USB_TRANSACTION_ERROR		equ 4
xHCI_CC_TRB_ERROR			equ 5
xHCI_CC_STALL_ERROR			equ 6
xHCI_CC_RESOURCE_ERROR			equ 7
xHCI_CC_BANDWIDTH_ERROR			equ 8
xHCI_CC_NO_SLOTS_ERROR			equ 9
xHCI_CC_INVALID_STREAM_TYPE_ERROR	equ 10 
xHCI_CC_SLOT_NOT_ENABLED_ERROR		equ 11
xHCI_CC_EP_NOT_ENABLED_ERROR		equ 12
xHCI_CC_SHORT_PACKET			equ 13
xHCI_CC_RING_UNDERRUN			equ 14
xHCI_CC_RING_OVERRUN			equ 15
xHCI_CC_VF_ER_FULL			equ 16
xHCI_CC_PARAMETER_ERROR			equ 17
xHCI_CC_BANDWIDTH_OVERRUN		equ 18
xHCI_CC_CONTEXT_STATE_ERROR		equ 19
xHCI_CC_NO_PING_RESPONSE_ERROR		equ 20
xHCI_CC_EVENT_RING_FULL_ERROR		equ 21
xHCI_CC_INCOMPATIBLE_DEVICE_ERROR	equ 22
xHCI_CC_MISSED_SERVICE_ERROR		equ 23
xHCI_CC_COMMAND_RING_STOPPED		equ 24
xHCI_CC_COMMAND_ABORTED			equ 25
xHCI_CC_STOPPED				equ 26
xHCI_CC_STOPPED_LENGTH_INVAID		equ 27
xHCI_CC_MAX_EXIT_LATENCY_TOO_LARGE_ERROR	equ 29
xHCI_CC_ISOCH_BUFFER_OVERRUN		equ 31
xHCI_CC_EVENT_LOST_ERROR		equ 32
xHCI_CC_UNDEFINED_ERROR			equ 33
xHCI_CC_INVALID_STREAM_ID_ERROR		equ 34
xHCI_CC_SECONDARY_BANDWIDTH_ERROR	equ 35
xHCI_CC_SPLIT_TRANSACTION_ERROR		equ 36


usbkeylayoutlower:
db 0, 0, 0, 0, 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', 0x1C, 0, 0x0E, 0, ' ', '-', '=', '[', ']', "\", 0, ';', "'", '`', ',', '.', '/', 0
; usbkeylayoutupper:
; db 0, 0, 0, 0, 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', 0x1C, 0, 0x0E, 0, ' ', '_', '+', '{', '}', '|', 0, ':', '"', '~', '<', '>', '?', 0
; ; 0e = backspace
; ; 1c = enter
; ; =============================================================================
; ; EOF