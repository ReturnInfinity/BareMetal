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

	; Mark controller memory as un-cacheable
	mov rax, [os_xHCI_Base]
	shr rax, 18
	and al, 0b11111000		; Clear the last 3 bits
	mov rdi, 0x10000		; Base of low PDE
	add rdi, rax
	mov rax, [rdi]
	btc rax, 3			; Clear PWT to disable caching
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
	jnc xhci_init_not32byte		; If bit is clear then use 32 bytes
	mov dword [xhci_csz], 64	; Otherwise set to 64
xhci_init_not32byte:
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
	btc eax, 0			; Clear RS (bit 0)
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
	mov rax, os_usb_ERS		; Starting Address of Event Ring Segment
	mov rdi, os_usb_ERST		; Starting Address of Event Ring Segment Table
	mov [rdi], rax			; Ring Segment Base Address
	mov eax, 32				; Size of Event Ring Segment
	mov [rdi+8], eax		; Ring Segment Size (bits 15:0)
	xor eax, eax
	mov [rdi+12], eax

	; Configure Event Ring for Primary Interrupter (Interrupt 0)
	mov rdi, [xhci_rt]
	add rdi, xHCI_IR_0		; Interrupt Register 0
	xor eax, eax			; Interrupt Enable (bit 1), Interrupt Pending (bit 0)
	mov [rdi+0x00], eax		; Interrupter Management (IMAN)
	mov eax, 64
	mov [rdi+0x04], eax		; Interrupter Moderation (IMOD)
	mov eax, 1			; ERSTBA points to 1 Segment Table
	mov [rdi+0x08], eax		; Event Ring Segment Table Size (ERSTSZ)
	add rax, os_usb_ERS
	mov [rdi+0x18], rax		; Event Ring Dequeue Pointer (ERDP)
	mov rax, os_usb_ERST
	mov [rdi+0x10], rax		; Event Ring Segment Table Base Address (ERSTBA)

	; Start Controller
	mov eax, 0x01			; Set bits 0 (RS)
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

	; Initialize Input Context
	; TODO - clear memory if this will be re-used later on
	mov rdi, os_usb_IDC
	; Set Control Context
	mov dword [rdi+0], 0x00000000
	mov dword [rdi+4], 0x00000003	; Set A01 and A00 as we want Control EP0 and Slot, respectively
	; Set Slot Context
	mov eax, [xhci_csz]
	add rdi, rax
	mov dword [rdi+0], 0x08300000	; Set Context Entries (31:27) to 1, set Speed (23:20)
	mov dword [rdi+4], 0x00050000	; Set Root Hub Port Number (23:16)
	; Set Endpoint Context
	mov eax, [xhci_csz]
	add rdi, rax
	mov dword [rdi+0], 0x00000000
	mov dword [rdi+4], 0x00080026	; Set Max Packet Size (31:16), EP Type (5:3), CErr (2:1)
	mov rax, os_usb_TR0		; Address of Transfer Ring
	bts rax, 0			; DCS
	mov qword [rdi+8], rax
	mov dword [rdi+16], 0x00000008	; Set Average TRB Length (15:0)

	; Build a TRB for Set Address in the Command Ring
	mov rdi, os_usb_CR
	add rdi, 16
	mov rax, os_usb_IDC		; Address of the Input Context
	stosq				; dword 0 & 1
	xor eax, eax
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
	mov eax, 0x00030841		; TRT (bits 17:16), TRB Type (15:10), IDT (bit 6), Cycle (0)
	stosd				; dword 3 - TRT (17:16), TRB Type (15:10), IDT (6), IOC (5), C (0)
	; Data Stage
	mov rax, os_usb_data0
	stosq				; dword 0 & 1 - Data Buffer (63:0)
	mov eax, 0x00000008		; Request 8 bytes
	stosd				; dword 2 - Interrupter Target (31:22), TD Size (21:17), TRB Transfer Length (16:0)
	mov eax, 0x00010C01
	stosd				; dword 3 - DIR (16), TRB Type (15:10), IDT (6), IOC (5), CH (4), NS (3), ISP (2), ENT (1), C (0)
	; Status Stage
	xor eax, eax
	stosq				; dword 0 & 1 - Reserved Zero
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001013		; TRB Type (15:10), Chain (4), ENT (1), Cycle (0)
	stosd				; dword 3 - DIR (16), TRB Type (15:10), IOC (5), CH (4), ENT (1), C (0)
	; Event Data
	mov rax, os_usb_data1
	stosq				; dword 0 & 1
	xor eax, eax
	stosd				; dword 2
	mov eax, 0x00001C21
	stosd				; dword 3

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
	stosd				; dword 0
	mov eax, ebx			; BL contains length
	shl eax, 16
	stosd				; dword 1
	mov eax, 0x00000008
	stosd				; dword 2
	mov eax, 0x00030841		; TRT (bits 17:16), TRB Type (15:10), IDT (bit 6), Cycle (0)
	stosd				; dword 3
	; Data Stage
	mov rax, os_usb_data0
	stosq				; dword 0 & 1
	mov eax, ebx			; BL contains length
	stosd				; dword 2
	mov eax, 0x00010C01
	stosd				; dword 3
	; Status Stage
	xor eax, eax
	stosq				; dword 0 & 1
	stosd				; dword 2
	mov eax, 0x00001013		; TRB Type (15:10), Chain (4), ENT (1), Cycle (0)
	stosd				; dword 3
	; Event Data
	mov rax, os_usb_data1
	add rax, 0x40
	stosq				; dword 0 & 1
	xor eax, eax
	stosd				; dword 2
	mov eax, 0x00001C21
	stosd				; dword 3

	; Ring doorbell for Slot 1
	mov eax, 1
	push rdi
	mov rdi, [xhci_db]
	add rdi, 4
	stosd				; Write to the Doorbell Register
	pop rdi

	mov eax, 100000
	call b_delay

	; Request 9 bytes from Configuration Descriptor

	; Setup Stage
	mov rax, 0x02000680		; 0x02 Configuration Descriptor
	stosd				; dword 0
	mov eax, 0x00090000
	stosd				; dword 1
	mov eax, 0x00000008
	stosd				; dword 2
	mov eax, 0x00030841		; TRT (bits 17:16), TRB Type (15:10), IDT (bit 6), Cycle (0)
	stosd				; dword 3
	; Data Stage
	mov rax, os_usb_data0
	add rax, 0x20
	stosq				; dword 0 & 1
	mov eax, 0x00000009
	stosd				; dword 2
	mov eax, 0x00010C01
	stosd				; dword 3
	; Status Stage
	xor eax, eax
	stosq				; dword 0 & 1
	stosd				; dword 2
	mov eax, 0x00001013		; TRB Type (15:10), Chain (4), ENT (1), Cycle (0)
	stosd				; dword 3
	; Event Data
	mov rax, os_usb_data1
	add rax, 0x40
	stosq				; dword 0 & 1
	xor eax, eax
	stosd				; dword 2
	mov eax, 0x00001C21
	stosd				; dword 3

	; Ring doorbell for Slot 1
	mov eax, 1
	push rdi
	mov rdi, [xhci_db]
	add rdi, 4
	stosd				; Write to the Doorbell Register
	pop rdi

	mov eax, 100000
	call b_delay

	; Request full data from Configuration Descriptor

	xor ebx, ebx
	mov bl, [os_usb_data0+0x20+2]	; BL contains length
	mov bh, [os_usb_data0+0x20+3]	; BH contains higher byte of length

	; Setup Stage
	mov rax, 0x02000680		; 0x02 Configuration Descriptor
	stosd				; dword 0
	mov eax, ebx			; BL contains length
	shl eax, 16
	stosd				; dword 1
	mov eax, 0x00000008
	stosd				; dword 2
	mov eax, 0x00030841		; TRT (bits 17:16), TRB Type (15:10), IDT (bit 6), Cycle (0)
	stosd				; dword 3
	; Data Stage
	mov rax, os_usb_data0
	add rax, 0x20
	stosq				; dword 0 & 1
	mov eax, ebx			; BL contains length
	stosd				; dword 2
	mov eax, 0x00010C01
	stosd				; dword 3
	; Status Stage
	xor eax, eax
	stosq				; dword 0 & 1
	stosd				; dword 2
	mov eax, 0x00001013		; TRB Type (15:10), Chain (4), ENT (1), Cycle (0)
	stosd				; dword 3
	; Event Data
	mov rax, os_usb_data1
	add rax, 0x40
	stosq				; dword 0 & 1
	xor eax, eax
	stosd				; dword 2
	mov eax, 0x00001C21
	stosd				; dword 3

	; Ring doorbell for Slot 1
	mov eax, 1
	push rdi
	mov rdi, [xhci_db]
	add rdi, 4
	stosd				; Write to the Doorbell Register
	pop rdi

	mov eax, 100000
	call b_delay

	; Request 32 bytes from String Descriptor 2

	; Setup Stage
	mov rax, 0x03020680		; 0x03 String Desc, 0x02 Product Desc
	stosd				; dword 0
	mov eax, 0x00200000
	stosd				; dword 1
	mov eax, 0x00000008
	stosd				; dword 2
	mov eax, 0x00030841		; TRT (bits 17:16), TRB Type (15:10), IDT (bit 6), Cycle (0)
	stosd				; dword 3
	; Data Stage
	mov rax, os_usb_data0
	add rax, 0x60
	stosq				; dword 0 & 1
	mov eax, 0x00000020
	stosd				; dword 2
	mov eax, 0x00010C01
	stosd				; dword 3
	; Status Stage
	xor eax, eax
	stosq				; dword 0 & 1
	stosd				; dword 2
	mov eax, 0x00001013		; TRB Type (15:10), Chain (4), ENT (1), Cycle (0)
	stosd				; dword 3
	; Event Data
	mov rax, os_usb_data1
	stosq				; dword 0 & 1
	xor eax, eax
	stosd				; dword 2
	mov eax, 0x00001C21
	stosd				; dword 3

	; Ring doorbell for Slot 1
	mov eax, 1
	push rdi
	mov rdi, [xhci_db]
	add rdi, 4
	stosd				; Write to the Doorbell Register
	pop rdi

	mov eax, 100000
	call b_delay

	push rdi
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
	pop rdi
	; TODO - Read the event code to verify success

	mov eax, 100000
	call b_delay

	push rdi
	; Configure the endpoint
	mov rdi, os_usb_IDC
	; Set Control Context
	mov dword [rdi+4], 0x00000009
	; Set Slot Context
	mov eax, [xhci_csz]
	add rdi, rax
	mov dword [rdi+0], 0xf8300000	; Set Context Entries (31:27) to 1, set Speed (23:20)
	mov dword [rdi+4], 0x00050000	; Set Root Hub Port Number (23:16)
	; Set Endpoint Context
	mov eax, [xhci_csz]
	add rdi, rax
	mov dword [rdi+0], 0x00000000
	mov dword [rdi+4], 0x00040026	; Set Max Packet Size (31:16), EP Type (5:3), CErr (2:1)
	mov rax, os_usb_TR0		; Address of Transfer Ring
	bts rax, 0			; DCS
	mov qword [rdi+8], rax
	mov dword [rdi+16], 0x00000008	; Set Average TRB Length (15:0)
	; Set EP1 In
	mov eax, [xhci_csz]
	add rdi, rax
	add rdi, rax
	mov dword [rdi+0], 0x00060000
	mov dword [rdi+4], 0x0004003e
	mov rax, os_usb_TR0
	add rax, 0x200
	bts rax, 0
	mov qword [rdi+8], rax
	mov dword [rdi+16], 0x00040004

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
	pop rdi

	; ---------------------------------------
	; Set Configuration Device
	; ---------------------------------------
xhci_set_conifguration_device:	
	; Load configuration value from configuration descriptor
	xor ebx, ebx  
	mov bl, [os_usb_data0+0x20+5]    ; Load bConfigurationValue (offset 5)

	; Setup Stage
	mov rax, 0x01000900          ; bmRequestType: Host to Device, Standard, Interface
	stosd                       ; dword 0
	xor eax, eax                ; 
	stosd                       ; dword 1
	xor eax, 0x00000008
	stosd                       ; dword 2
	mov eax, 0x00030841         ; TRT = 3 (OUT Transfer), TRB Type (15:10), IDT (bit 6), Cycle (bit 0)
	stosd                       ; dword 3

	; Status Stage (IN Transfer) - No Data
	xor rax, rax
	stosq                       ; dword 0 & 1
	stosd                       ; dword 2
	mov eax, 0x00001013         ; TRB Type (15:10 = Status Stage), Cycle bit set
	stosd                       ; dword 3

	; Event Data TRB
	mov rax, os_usb_data1
	add rax, 0x40
	stosq                       ; dword 0 & 1
	xor eax, eax
	stosd                       ; dword 2
	mov eax, 0x00001C21         ; TRB Type (15:10 = Event Data), Cycle bit set
	stosd                       ; dword 3

	; Ring the doorbell for Slot 1
	mov eax, 1
	push rdi
	mov rdi, [xhci_db]
	add rdi, 4
	stosd                ; Write to the Doorbell Register
	pop rdi

	mov eax, 100000
	call b_delay
	
	; ---------------------------------------
	; Get HID Report Descriptor
	; ---------------------------------------
xhci_get_hid_descriptor:		
	xor ebx, ebx
	mov bl, [os_usb_data0+0x30+9]  ; Load LSB of wReportDescriptorLength
	mov bh, [os_usb_data0+0x30+10] ; Load MSB of wReportDescriptorLength
	mov r12, rbx                   ; Store the length in r12

	; Setup Stage
	mov rax, 0x22000681         ; bmRequestType (0x81) | bRequest (0x06) | wValue (0x22 << 8)
	stosd                       ; dword 0
	mov eax, r12d		        ; DWORD 1: wLength (52 bytes) | wIndex (Interface 0)
	shl rax, 16
	stosd                       ; dword 1
	mov eax, 0x00000008			; TRB Length (8 bytes)
	stosd                       ; dword 2
	mov eax, 0x00030841         ; TRT = 3 (OUT Transfer), TRB Type (15:10), IDT (bit 6), Cycle (bit 0)
	stosd                       ; dword 3

	; Data Stage (OUT Transfer) - Send 1 byte
	mov rax, os_usb_data0
	add rax, 0x80
	stosq                       ; dword 0 & 1
	mov eax, r12d		        ; byte to send
	stosd                       ; dword 2
	mov eax, 0x00010C01         ; OUT Transfer, Cycle bit set
	stosd                       ; dword 3

	; Status Stage (IN Transfer) - No Data
	xor rax, rax
	stosq                       ; dword 0 & 1
	stosd                       ; dword 2
	mov eax, 0x00001013         ; TRB Type (15:10 = Status Stage), Cycle bit set
	stosd                       ; dword 3

	; Event Data TRB
	mov rax, os_usb_data1
	add rax, 0x40
	stosq                       ; dword 0 & 1
	xor eax, eax
	stosd                       ; dword 2
	mov eax, 0x00001C21         ; TRB Type (15:10 = Event Data), Cycle bit set
	stosd                       ; dword 3

	; Ring the doorbell for Slot 1
	mov eax, 1
	push rdi
	mov rdi, [xhci_db]
	add rdi, 4
	stosd                ; Write to the Doorbell Register
	pop rdi

	mov eax, 100000
	call b_delay

	; ---------------------------------------
	; Get Protocol HID
	; ---------------------------------------
xhci_get_protocol_hid:
	xor ebx, ebx
	mov bl, [os_usb_data0+0x20+11]  ; Load Interface Number


	; Setup Stage
	mov rax, 0x000003A1         ; bmRequestType (0xA1) | bRequest (0x03) 
	shl rbx, 16					; wValue(Interface Num)
	or rax, rbx					
	stosd                       ; dword 0
	mov eax, 0x00010000         ; DWORD 1: wLength (1 bytes) | wIndex (Interface 0)
	stosd                       ; dword 1
	mov eax, 0x00000008			; TRB Length (8 bytes)
	stosd                       ; dword 2
	mov eax, 0x00030841         ; TRT = 3 (OUT Transfer), TRB Type (15:10), IDT (bit 6), Cycle (bit 0)
	stosd                       ; dword 3

	; Data Stage (OUT Transfer) - Send 1 byte
	mov rax, os_usb_data0
	add rax, 0xC0 
	stosq                       ; dword 0 & 1
	mov eax, 1		        	; byte to send
	stosd                       ; dword 2
	mov eax, 0x00010C01         ; OUT Transfer, Cycle bit set
	stosd                       ; dword 3

	; Status Stage (IN Transfer) - No Data
	xor rax, rax
	stosq                       ; dword 0 & 1
	stosd                       ; dword 2
	mov eax, 0x00001013         ; TRB Type (15:10 = Status Stage), Cycle bit set
	stosd                       ; dword 3

	; Event Data TRB
	mov rax, os_usb_data1
	add rax, 0x40
	stosq                       ; dword 0 & 1
	xor eax, eax
	stosd                       ; dword 2
	mov eax, 0x00001C21         ; TRB Type (15:10 = Event Data), Cycle bit set
	stosd                       ; dword 3

	; Ring the doorbell for Slot 1
	mov eax, 1
	push rdi
	mov rdi, [xhci_db]
	add rdi, 4
	stosd                ; Write to the Doorbell Register
	pop rdi

	mov eax, 100000
	call b_delay

	; ---------------------------------------
	; Set Protocol HID
	; ---------------------------------------
xhci_set_protocol_hid:
	; Setup Stage
	mov rax, 0x01000B21         ; bmRequestType (0x21) | bRequest (0x0B) 			
	stosd                       ; dword 0
	mov eax, 0x00000000         ; DWORD 1: wLength (0 bytes) | wIndex (Interface 0)
	stosd                       ; dword 1
	mov eax, 0x00000008			; TRB Length (8 bytes)
	stosd                       ; dword 2
	mov eax, 0x00030841         ; TRT = 3 (OUT Transfer), TRB Type (15:10), IDT (bit 6), Cycle (bit 0)
	stosd                       ; dword 3

	; Status Stage (IN Transfer) - No Data
	xor rax, rax
	stosq                       ; dword 0 & 1
	stosd                       ; dword 2
	mov eax, 0x00001013         ; TRB Type (15:10 = Status Stage), Cycle bit set
	stosd                       ; dword 3

	; Event Data TRB
	mov rax, os_usb_data1
	add rax, 0x40
	stosq                       ; dword 0 & 1
	xor eax, eax
	stosd                       ; dword 2
	mov eax, 0x00001C21         ; TRB Type (15:10 = Event Data), Cycle bit set
	stosd                       ; dword 3

	; Ring the doorbell for Slot 1
	mov eax, 1
	push rdi
	mov rdi, [xhci_db]
	add rdi, 4
	stosd                ; Write to the Doorbell Register
	pop rdi

	mov eax, 100000
	call b_delay

	jmp xhci_init_done

xhci_init_error:
	jmp $

xhci_init_done:

	pop rdx
	ret

xhci_caplen:	db 0
xhci_maxslots:	db 0
xhci_op:	dq 0			; Start of Operational Registers
xhci_db:	dq 0			; Start of Doorbell Registers
xhci_rt:	dq 0			; Start of Runtime Registers
xhci_csz:	dd 32			; Default Context Size
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


; =============================================================================
; EOF