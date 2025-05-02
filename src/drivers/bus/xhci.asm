; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; xHCI (USB 3) Driver
; =============================================================================


; -----------------------------------------------------------------------------
; Initialize xHCI controller
;  IN:	RDX = Packed Bus address (as per syscalls/bus.asm)
xhci_init:
	push rsi			; Used in init_usb
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
xhci_init_msix_check:
	mov dl, 1
	call os_bus_read		; Read register 1 for Status/Command
	bt eax, 20			; Check bit 4 of the Status word (31:16)
	jnc xhci_init_error		; If if doesn't exist then bail out
	mov dl, 13
	call os_bus_read		; Read register 13 for the Capabilities Pointer (7:0)
	and al, 0xFC			; Clear the bottom two bits as they are reserved
xhci_init_msix_check_cap_next:
	shr al, 2			; Quick divide by 4
	mov dl, al
	call os_bus_read
	cmp al, 0x11
	je xhci_init_msix
xhci_init_msix_check_cap_next_offset:
	shr eax, 8			; Shift pointer to AL
	cmp al, 0x00			; End of linked list?
	jne xhci_init_msix_check_cap_next	; If not, continue reading
	jmp xhci_init_msi_check		; Otherwise bail out and check for MSI
xhci_init_msix:
	push rdx
	; Enable MSI-X, Mask it, Get Table Size
	; Example MSI-X Entry (From QEMU xHCI Controller)
	; 000FA011 <- Cap ID 0x11 (MSI-X), next ptr 0xA0, message control 0x000F - Table size is bits 10:0 so 0x0F
	; 00003000 <- BIR (2:0) is 0x0 so BAR0, Table Offset (31:3) - 8-byte aligned so clear low 3 bits - 0x3000 in this case
	; 00003800 <- Pending Bit BIR (2:0) and Pending Bit Offset (31:3) - 0x3800 in this case
	; Message Control - Enable (15), Function Mask (14), Table Size (10:0)
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
	; Unmask MSI-X
	pop rdx
	call os_bus_read
	btr eax, 30			; Clear Function Mask
	call os_bus_write
	jmp xhci_init_msix_msi_done

	; Check for MSI in PCI Capabilities
xhci_init_msi_check:
	mov dl, 1
	call os_bus_read		; Read register 1 for Status/Command
	bt eax, 20			; Check bit 4 of the Status word (31:16)
	jnc xhci_init_error		; If if doesn't exist then bail out
	mov dl, 13
	call os_bus_read		; Read register 13 for the Capabilities Pointer (7:0)
	and al, 0xFC			; Clear the bottom two bits as they are reserved
xhci_init_msi_check_cap_next:
	shr al, 2			; Quick divide by 4
	mov dl, al
	call os_bus_read
	cmp al, 0x05
	je xhci_init_msi
xhci_init_msi_check_cap_next_offset:
	shr eax, 8			; Shift pointer to AL
	cmp al, 0x00			; End of linked list?
	jne xhci_init_msi_check_cap_next	; If not, continue reading
	jmp xhci_init_error		; Otherwise bail out
xhci_init_msi:
	push rdx
	; Enable MSI
	; Example MSI Entry (From Intel test system)
	; 00869005 <- Cap ID 0x05 (MSI), next ptr 0x90, message control 0x0x0086 (64-bit, MMC 8)
	; 00000000 <- Message Address Low
	; 00000000 <- Message Address High
	; 00000000 <- Message Data (15:0)
	; 00000000 <- Mask (only exists if Per-vector masking is enabled)
	; 00000000 <- Pending (only exists if Per-vector masking is enabled)
	; Message Control - Per-vector masking (8), 64-bit (7), Multiple Message Enable (6:4), Multiple Message Capable (3:1), Enable (0)
	; MME/MMC 000b = 1, 001b = 2, 010b = 4, 011b = 8, 100b = 16, 101b = 32
	; Todo - Test bit 7, Check Multiple Message Capable, copy to Multiple Message Enable
	add dl, 1
	mov rax, [os_LocalAPICAddress]	; 0xFEE for bits 31:20, Dest (19:12), RH (3), DM (2)
	call os_bus_write		; Store Message Address Low
	add dl, 1
	shr rax, 32			; Rotate the high bits to EAX
	call os_bus_write		; Store Message Address High
	add dl, 1
	mov eax, 0x000040A0		; Trigger Mode (15), Level (14), Delivery Mode (10:8), Vector (7:0)
	call os_bus_write		; Store Message Data
	sub dl, 3
	call os_bus_read		; Get Message Control
	bts eax, 21			; Debug - See MME to 8
	bts eax, 20			; Debug - See MME to 8
	bts eax, 16			; Set Enable
	call os_bus_write		; Update Message Control
	pop rdx

xhci_init_msix_msi_done:
	; Create a gate in the IDT
	mov edi, 0xA0
	mov rax, xhci_int0
	call create_gate		; Create the gate for the Primary Interrupter
	mov edi, 0xA1
	mov rax, xhci_int1
	call create_gate		; Create the gate for Interrupter 1 (Keyboard)

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
	jb xhci_init_error
	mov eax, [rsi+xHCI_HCSPARAMS1]	; Gather MaxSlots (bits 7:0) and MaxPort (31:24)
	mov byte [xhci_maxslots], al
	rol eax, 8
	mov byte [xhci_maxport], al
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
	call xhci_reset

	; Set flag that xHCI was enabled
	or qword [os_SysConfEn], 1 << 5

xhci_init_done:
	pop rdx
	pop rsi

	add rsi, 15
	mov byte [rsi], 1		; Mark driver as installed in Bus Table
	sub rsi, 15

	ret

xhci_init_error:
	jmp $
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; xhci_reset - Reset xHCI controller
xhci_reset:
	push rdi
	push rsi
	push rcx
	push rbx
	push rax

	; Halt the controller
xhci_reset_halt:
	mov rsi, [xhci_op]		; xHCI Operational Registers Base
	mov eax, [rsi+xHCI_USBCMD]	; Read current Command Register value
	bt eax, 0			; Check RS (bit 0)
	jnc xhci_reset_halt_done	; If the bit was clear, proceed onward
	btr eax, 0			; Clear RS (bit 0)
	mov [rsi+xHCI_USBCMD], eax	; Write updated Command Register value
	mov rax, 20000			; Wait 20ms (20000µs)
	call b_delay
	mov eax, [rsi+xHCI_USBSTS]	; Read Status Register
	bt eax, 0			; Check HCHalted (bit 0) - it should be 1
	jnc xhci_reset_error		; Bail out if HCHalted wasn't cleared after 20ms
xhci_reset_halt_done:

	; Clear memory controller will be using
	mov rdi, os_usb_mem
	xor eax, eax
	mov ecx, 32768			; 32768 * 8 = 262144 bytes
	rep stosq

	; Reset the controller
xhci_reset_reset:
	mov eax, [rsi+xHCI_USBCMD]	; Read current Command Register value
	bts eax, 1			; Set HCRST (bit 1)
	mov [rsi+xHCI_USBCMD], eax	; Write updated Command Register value
	mov rax, 100000			; Wait 100ms (100000µs)
	call b_delay
	mov eax, [rsi+xHCI_USBSTS]	; Read Status Register
	bt eax, 11			; Check CNR (bit 11)
	jc xhci_reset_error		; Bail out if CNR wasn't cleared after 100ms
	mov eax, [rsi+xHCI_USBCMD]	; Read current Command Register value
	bt eax, 1			; Check HCRST (bit 1)
	jc xhci_reset_error		; Bail out if HCRST wasn't cleared after 100ms

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
	mov ebx, [xhci_csz]
	shl ebx, 5
	mov rcx, 8
	mov rax, os_usb_DC		; Start of the Device Context Entries
xhci_reset_build_DC:
	stosq
	add rax, rbx			; Add size of Context (1024 or 2048 bytes)
	dec rcx
	jnz xhci_reset_build_DC

	; Build scratchpad entries
	mov rdi, os_usb_scratchpad
	mov rax, os_usb_scratchpad
	mov rcx, 4			; Create 4 4KiB scratchpad entries
xhci_reset_build_scratchpad:
	add rax, 4096
	stosq
	dec rcx
	jnz xhci_reset_build_scratchpad

	; Configure Segment Tables
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
	mov eax, 256			; 256 * 16 bytes each = 4096 bytes
	mov [rdi+8], eax		; Ring Segment Size (bits 15:0)
	xor eax, eax
	mov [rdi+12], eax
	; Segment table for Interrupter 1
	mov rax, os_usb_ERS+4096	; Starting Address of Event Ring Segment
	mov rdi, os_usb_ERST+4096	; Starting Address of Event Ring Segment Table
	mov [rdi], rax			; Ring Segment Base Address
	mov eax, 256			; 256 * 16 bytes each = 4096 bytes
	mov [rdi+8], eax		; Ring Segment Size (bits 15:0)
	xor eax, eax
	mov [rdi+12], eax

	; Configure Interrupter Event Rings
	; Event Ring for Primary Interrupter (Interrupt 0)
	mov rdi, [xhci_rt]
	add rdi, xHCI_IR_0		; Interrupt Register 0
	mov eax, 2			; Interrupt Enable (bit 1), Interrupt Pending (bit 0)
	mov [rdi+0x00], eax		; Interrupter Management (IMAN)
	mov eax, 64
	mov [rdi+0x04], eax		; Interrupter Moderation (IMOD)
	mov eax, 1			; ERSTBA points to 1 Segment Table
	mov [rdi+0x08], eax		; Event Ring Segment Table Size (ERSTSZ)
	add rax, os_usb_ERS
	mov [rdi+0x18], rax		; Event Ring Dequeue Pointer (ERDP)
	mov rax, os_usb_ERST
	mov [rdi+0x10], rax		; Event Ring Segment Table Base Address (ERSTBA)
	; Event Ring for Interrupter 1
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

	; Start Controller
	mov eax, 0x05			; Set bit 0 (RS) and bit 2 (INTE)
	mov [rsi+xHCI_USBCMD], eax

	; Verify HCHalted is clear
xhci_reset_check_start:
	mov eax, [rsi+xHCI_USBSTS]	; Read Status Register
	bt eax, 0			; Check HCHalted (bit 0) - it should be 0
	jc xhci_reset_check_start

xhci_reset_done:
	pop rax
	pop rbx
	pop rcx
	pop rsi
	pop rdi
	ret

xhci_reset_error:
	jmp $
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; xhci_enumerate_devices - Enumerate devices connected to xHCI controller
xhci_enumerate_devices:
	push rdi
	push rsi
	push rdx
	push rcx
	push rbx
	push rax

	mov rsi, [xhci_op]		; xHCI Operational Registers Base

	; Check the available ports and reset them
	xor ecx, ecx			; Slot counter
	xor edx, edx			; Max ports
	mov dl, byte [xhci_maxport]
xhci_check_next:
	mov ebx, 0x400			; Offset to start of Port Registers
	shl ecx, 4			; Quick multiply by 16
	add ebx, ecx			; Add offset to EBX
	shr ecx, 4			; Quick divide by 16
	mov eax, [rsi+rbx]		; Read PORTSC
	bt eax, 0			; Current Connect Status
	jnc xhci_reset_skip
	bts eax, 4			; Port Reset
	mov [rsi+rbx], eax		; Write PORTSC
xhci_reset_skip:
	inc ecx
	cmp ecx, edx
	jne xhci_check_next

	; Wait for USB devices to be ready
	mov eax, 100000
	call b_delay

	; At this point the event ring should contain some port status change event entries
	; They should appear as follows:
	; 0xXX000000 0x00000000 0x01000000 0x00008801
	; dword 0 - Port ID number (31:24)
	; dword 1 - Reserved
	; dword 2 - Completion code (31:24)
	; dword 3 - Type 34 (15:10), C (0)

	; Check Event ring for xHCI_ETRB_PSC and gather enabled ports
	xor ecx, ecx
	mov rdi, xhci_portlist
	mov rsi, os_usb_ERS
	sub rsi, 16
xhci_check_port:
	add rsi, 16
	mov eax, [rsi+12]		; Load dword 3
	shr eax, 10			; Shift Type to AL
	cmp al, 0			; End of list
	je xhci_check_port_end
	cmp al, xHCI_ETRB_PSC
	je xhci_check_port_store
	jmp xhci_check_port
xhci_check_port_store:
	inc cl
	mov al, [rsi+3]
	stosb
	jmp xhci_check_port
xhci_check_port_end:
	mov byte [xhci_portcount], cl

xhci_search_devices:

	; Check that at least 1 port was enabled
	cmp byte [xhci_portcount], 0
	je xhci_enumerate_devices_end	; If no active ports then bail out

	; At this point xhci_portcount contains the number of activated ports
	; and xhci_portlist is a list of the port numbers

	; Clear Transfer and Event ring (in case this xhci_search_devices is called more than once)
	mov rdi, os_usb_TR0
	mov ecx, 512
	xor eax, eax
	rep stosq

	; Enable Slot Command TRB
	; ┌───────────────────────────────────────────────────────────────────────────────────────────────┐
	; |31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00|
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Zero                                                                                          |
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Zero                                                                                          |
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Zero                                                                                          |
	; ├───────────────────────────────────────────────┬─────────────────┬──────────────────────────┬──┤
	; | Zero                                          | 9               | Reserved Zero            |C |
	; └───────────────────────────────────────────────┴─────────────────┴──────────────────────────┴──┘
	; Ex:
	;	0x00000000 0x00000000 0x00000000 0x00002401

	; Build a TRB for Enable Slot in the Command Ring
	mov rdi, os_usb_CR
	add rdi, [xhci_croff]
	push rdi			; Save the Address of the Enable Slot command
	xor eax, eax
	stosd				; Store dword 0
	stosd				; Store dword 1
	stosd				; Store dword 2
	mov al, xHCI_CTRB_ESLOT		; Enable Slot opcode
	shl eax, 10			; Shift opcode to bits 15:10
	bts eax, 0			; Cycle Bit
	stosd				; Store dword 3
	add qword [xhci_croff], 16

	; Ring the Doorbell for the Command Ring
	xor eax, eax
	xor ecx, ecx
	call xhci_ring_doorbell

	; Enable Slot Event TRB
	; ┌───────────────────────────────────────────────────────────────────────────────────────────────┐
	; |31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00|
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Address of Enable Slot TRB Lo                                                                 |
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Address of Enable Slot TRB Hi                                                                 |
	; ├───────────────────────┬───────────────────────────────────────────────────────────────────────┤
	; | CompCode              | Reserved Zero                                                         |
	; ├───────────────────────┴───────────────────────┬─────────────────┬──────────────────────────┬──┤
	; | Slot ID               | Reserved Zero         | 33              | Reserved Zero            |C |
	; └───────────────────────┴───────────────────────┴─────────────────┴──────────────────────────┴──┘
	; Ex:
	;	0xXXXXXXXX 0xXXXXXXXX 0x01000000 0xXX008401

	; Gather result from event ring
	pop rbx				; Restore the Address of the Enable Slot command
	call xhci_check_command_event	; Check for the event and return result in RAX

	; Check CompCode and gather Slot ID from event
	ror rax, 24			; Rotate RAX right by 24 bits to put CompCode in AL
	cmp al, 0x01
	jne xhci_enumerate_devices_end
	ror rax, 32			; Rotate RAX right by 32 bits to put Slot ID in AL
	mov [currentslot], al

	; Clear the IDC (Maximum of 2112 bytes)
	mov rdi, os_usb_IDC
	xor eax, eax
	mov ecx, 264			; 2112 / 8
	rep stosq

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
	;
	; Input Control Context
	; ┌───────────────────────────────────────────────────────────────────────────────────────────────┐
	; |31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00|
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Drop Flags                                                                                    |
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Add Flags                                                                                     |
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Reserved Zero Padding                                                                         |
	; └───────────────────────────────────────────────────────────────────────────────────────────────┘
	;
	; Slot Context
	; ┌───────────────────────────────────────────────────────────────────────────────────────────────┐
	; |31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00|
	; ├──────────────┬──┬──┬──┬───────────┬───────────────────────────────────────────────────────────┤
	; | Cont Entries |Hu|MT|RZ| Speed     | Route String                                              |
	; ├──────────────┴──┴──┴──┼───────────┴───────────┬───────────────────────────────────────────────┤
	; | Number of Ports       | Root Hub Port Number  | Max Exit Latency                              |
	; ├───────────────────────┴─────┬───────────┬─────┼───────────────────────┬───────────────────────┤
	; | Interrupter Target          | RZ        | TTT | TT Port Num           | TT Hub Slot ID        |
	; ├──────────────┬──────────────┴───────────┴─────┴───────────────────────┼───────────────────────┤
	; | State        | Reserved Zero                                          | Device Address        |
	; ├──────────────┴────────────────────────────────────────────────────────┴───────────────────────┤
	; | Reserved Zero Padding                                                                         |
	; └───────────────────────────────────────────────────────────────────────────────────────────────┘
	;
	; Endpoint Context
	; ┌───────────────────────────────────────────────────────────────────────────────────────────────┐
	; |31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00|
	; ├───────────────────────┬───────────────────────┬──┬──────────────┬─────┬──────────────┬────────┤
	; | Max ESIT Payload High | Interval              |LS| MaxP Streams |Mult | Reserved     |EP State|
	; ├───────────────────────┴───────────────────────┼──┴──────────────┴─────┼──┬──┬────────┼─────┬──┤
	; | Max Packet Size                               | Max Burst Size        |H |RZ|EP Type |CErr |RZ|
	; ├───────────────────────────────────────────────┴───────────────────────┴──┴──┴─────┬──┴─────┴──┤
	; | TR Dequeue Pointer Low                                                            | Resv   |DC|
	; ├───────────────────────────────────────────────────────────────────────────────────┴────────┴──┤
	; | TR Dequeue Pointer High                                                                       |
	; ├───────────────────────────────────────────────┬───────────────────────────────────────────────┤
	; | Max ESIT Payload Low                          | Average TRB Length                            |
	; ├───────────────────────────────────────────────┴───────────────────────────────────────────────┤
	; | Reserved Zero Padding                                                                         |
	; └───────────────────────────────────────────────────────────────────────────────────────────────┘

	mov rdi, os_usb_IDC
	; Set Input Control Context
	; Skip Drop Flags
	mov dword [rdi+4], 0x00000003	; dword 1 - Add Flags - Set A01 and A00 as we want Endpoint Context 0 and Slot Context, respectively
	; Skip the rest of Input Control Context as it is already cleared
	; Set Slot Context
	mov eax, [xhci_csz]
	add rdi, rax
	; Read port speed from port register
	xor eax, eax
	mov al, [xhci_portlist]
	dec al
	shl eax, 4			; Multiply by 16
	add eax, 0x400			; Add 0x400 for Port Base
	add rax, [xhci_op]		; Add op base
	mov eax, [rax]			; Get PORTSC
	; Todo SHL by 10 and do a proper AND
	shr eax, 10			; Shift Port Speed (13:10) to (3:0)
	and eax, 0xF			; Clear upper bits of EAX
	shl eax, 20			; Shift Port Speed (3:0) to (23:20)
	bts eax, 27			; Set bit 27 for 1 Context Entry (31:27)
	mov dword [rdi+0], eax		; dword 0 - Context Entries (31:27) to 1, set Speed (23:20)
	xor eax, eax
	mov al, [xhci_portlist]		; Collect port number
	shl eax, 16			; Shift value to 23:16
	mov dword [rdi+4], eax		; dword 1 - Root Hub Port Number (23:16)
	; Skip the rest of the Slot Context as it is already cleared
	; Set Endpoint Context 0
	mov eax, [xhci_csz]
	add rdi, rax
	; TODO Set interval
	; Skip dword 0
	mov dword [rdi+4], 0x00080026	; dword 1 - Max Packet Size (31:16) to 8, EP Type (5:3) to 4 (Control), CErr (2:1) to 3
	mov rax, os_usb_TR0		; Address of Transfer Ring
	bts rax, 0			; DCS
	mov qword [rdi+8], rax		; dword 2 & 3
	mov dword [rdi+16], 0x00000008	; dword 4 - Average TRB Length (15:0)
	; Skip the rest of Endpoint Context 0 as it is already cleared

	; Set Address Command TRB
	; ┌───────────────────────────────────────────────────────────────────────────────────────────────┐
	; |31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00|
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Address of Input Context Lo                                                                   |
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Address of Input Context Hi                                                                   |
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Reserved Zero                                                                                 |
	; ├───────────────────────┬───────────────────────┬─────────────────┬──┬───────────────────────┬──┤
	; | Slot ID               | Reserved Zero         | 11              |B | Reserved Zero         |C |
	; └───────────────────────┴───────────────────────┴─────────────────┴──┴───────────────────────┴──┘
	; Ex:
	;	0xXXXXXXXX 0xXXXXXXXX 0x00000000 0xXX002E01 (or 0xXX002C01 depending on B)

	; Build a TRB for Set Address in the Command Ring
	mov rdi, os_usb_CR
	add rdi, [xhci_croff]
	push rdi
	mov rax, os_usb_IDC		; Address of the Input Context
	stosq				; dword 0 & 1
	xor eax, eax			; Reserved
	stosd				; dword 2
	mov al, [currentslot]
	shl eax, 24			; Set Slot ID (31:24)
	mov al, xHCI_CTRB_ADDRD
	shl ax, 10
;	bts eax, 9			; B
	bts eax, 0			; Cycle
	stosd				; dword 3
	add qword [xhci_croff], 16

	; Ring the Doorbell for the Command Ring
	xor eax, eax
	xor ecx, ecx
	call xhci_ring_doorbell

	; Set Address Event TRB
	; ┌───────────────────────────────────────────────────────────────────────────────────────────────┐
	; |31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00|
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Address of Input Context Lo                                                                   |
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Address of Input Context Hi                                                                   |
	; ├───────────────────────┬───────────────────────────────────────────────────────────────────────┤
	; | CompCode              | Reserved Zero                                                         |
	; ├───────────────────────┴───────────────────────┬─────────────────┬──────────────────────────┬──┤
	; | Slot ID               | Reserved Zero         | 33              | Reserved Zero            |C |
	; └───────────────────────┴───────────────────────┴─────────────────┴──────────────────────────┴──┘
	; Ex:
	;	0xXXXXXXXX 0xXXXXXXXX 0x01000000 0xXX008401

	; Gather result from event ring
	pop rbx				; Restore the Address of the Set Address command
	call xhci_check_command_event

	; Check CompCode
	ror rax, 24			; Rotate RAX right by 24 bits to put CompCode in AL
	cmp al, 0x01
	jne xhci_enumerate_devices_end

	; Clear os_usb_data0
	mov rdi, os_usb_data0
	xor eax, eax
	mov ecx, 32			; 256 bytes
	rep stosq

	; Add TRBs to Transfer ring
	mov rdi, os_usb_TR0

	; Request 8 bytes from Device Descriptor to get the length and the Max Packet Size

	; Setup Stage
	mov eax, 0x01000680		; 0x01 Device Descriptor
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
	add qword [os_usb_evtoken], 1
	mov rax, [os_usb_evtoken]
	push rax
	stosq				; dword 0 & 1 - Data Buffer (63:0)
	xor eax, eax
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001E21		; TRB Type 7, BEI, IOC, C
	stosd				; dword 3 - TRB Type (15:10), BEI (9), IOC (5), CH (4), ENT (1), Cycle (0)

	; Ring the doorbell for current slot
	mov eax, 1			; EPID 1
	xor ecx, ecx
	mov cl, [currentslot]
	call xhci_ring_doorbell

	; Gather result from event ring
	pop rbx				; Restore the token value command
	call xhci_check_command_event

	; Check CompCode
	ror rax, 24			; Rotate RAX right by 24 bits to put CompCode in AL
	cmp al, 0x01
	jne xhci_enumerate_devices_end

;	; Build a TRB for Set Address in the Command Ring (with B cleared this time)
;	push rdi
;	mov rdi, os_usb_CR
;	add rdi, [xhci_croff]
;	push rdi			; Save the Address of the Set Address command
;	mov rax, os_usb_IDC		; Address of the Input Context
;	stosq				; dword 0 & 1
;	xor eax, eax			; Reserved
;	stosd				; dword 2
;	mov al, [currentslot]
;	shl eax, 24			; Set Slot ID (31:24)
;	mov al, xHCI_CTRB_ADDRD
;	shl ax, 10
;	bts eax, 0			; Cycle
;	stosd				; dword 3
;	add qword [xhci_croff], 16
;
;	; Ring the Doorbell for the Command Ring
;	xor eax, eax
;	xor ecx, ecx
;	call xhci_ring_doorbell
;
;	; Gather result from event ring
;	pop rbx				; Restore the Address of the Set Address command
;	call xhci_check_command_event
;	pop rdi
;
;	; Check CompCode
;	ror rax, 24			; Rotate RAX right by 24 bits to put CompCode in AL
;	cmp al, 0x01
;	jne xhci_enumerate_devices_end

	; Check first 8 bytes of Device Descriptor
	; Example from QEMU keyboard
	;
	; 0000: 0x12 0x01 0x00 0x02 0x00 0x00 0x00 0x40
	;
	; 1) Update Endpoint Context 0 Max Packet Size (to 0x40 in the case above)

	push rdi

	mov al, [os_usb_data0+7]	; Gather the Max Packet Size
	cmp al, 0x08			; Is it different from the default of 8?
	je xhci_skip_update_idc		; If not, skip updating the IDC
	mov rdi, os_usb_IDC
	mov eax, [xhci_csz]
	shl eax, 1
	add rdi, rax
	mov eax, [rdi+4]
	ror eax, 16
	mov al, [os_usb_data0+7]
	ror eax, 16
	mov [rdi+4], eax

	; 2) Run Evaluate Context

	; Build a TRB for Evaluate Context in the Command Ring
	mov rdi, os_usb_CR
	add rdi, [xhci_croff]
	push rdi
	mov rax, os_usb_IDC		; Address of the Input Context
	stosq				; dword 0 & 1
	xor eax, eax
	stosd				; dword 2
	mov al, [currentslot]
	shl eax, 24			; Set Slot ID (31:24)
	mov al, xHCI_CTRB_EVALC
	shl ax, 10
	bts eax, 0			; Cycle
	stosd				; dword 3
	add qword [xhci_croff], 16
	; 0xXXXXXXXX 0xXXXXXXXX 0x0000000 0x01003401

	; Ring the Doorbell for the Command Ring
	xor eax, eax
	xor ecx, ecx
	call xhci_ring_doorbell

	; Gather result from event ring
	pop rbx				; Restore the Address of the Evaluate Context command
	call xhci_check_command_event

	; Check CompCode
	ror rax, 24			; Rotate RAX right by 24 bits to put CompCode in AL
	cmp al, 0x01
	jne xhci_enumerate_devices_end

xhci_skip_update_idc:

	pop rdi

	; Request full data from Device Descriptor

	xor ebx, ebx
	mov bl, [os_usb_data0]		; BL contains Device Descriptor length

	; Setup Stage
	mov eax, 0x01000680		; 0x01 Device Descriptor
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
	add qword [os_usb_evtoken], 1
	mov rax, [os_usb_evtoken]
	push rax
	stosq				; dword 0 & 1 - Data Buffer (63:0)
	xor eax, eax
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001E21		; TRB Type 7, BEI, IOC, C
	stosd				; dword 3 - TRB Type (15:10), BEI (9), IOC (5), CH (4), ENT (1), Cycle (0)

	; Ring the doorbell for current slot
	mov eax, 1			; EPID 1
	xor ecx, ecx
	mov cl, [currentslot]
	call xhci_ring_doorbell

	; Gather result from event ring
	xor eax, eax
	pop rbx				; Restore the token value
	call xhci_check_command_event

	; Check CompCode
	ror rax, 24			; Rotate RAX right by 24 bits to put CompCode in AL
	cmp al, 0x01
	jne xhci_enumerate_devices_end

	; TODO - Check full Device Descriptor
	; Example from QEMU keyboard
	;
	; 0000: 0x12 0x01 0x00 0x02 0x00 0x00 0x00 0x40
	; 0008: 0x27 0x06 0x01 0x00 0x00 0x00 0x01 0x04
	; 0010: 0x0B 0x01
	;
	; Expanded out:
	; Length 0x12
	; Type 0x01
	; Release Num 0x0200
	; Device Class 0x00
	; Sub Class 0x00
	; Protocol 0x00
	; Max Packet Size 0x40
	; Vendor ID 0x0627
	; Product ID 0x0001
	; Device Release 0x0000
	; Manufacturer 0x01
	; Product 0x04
	; Serial Number 0x0B
	; Configurations 0x01
	;
	; Gather Vendor ID (offset 8) and Product ID (offset 10)
	; Build a table
	; Slot / Vendor / Product / Class / Protocol

	; Request 9 bytes from Configuration Descriptor

	; Setup Stage
	mov eax, 0x02000680		; 0x02 Configuration Descriptor
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
	mov eax, 0x00010C01		; DIR, TRB Type 3, C
	stosd				; dword 3 - DIR (16), TRB Type (15:10), IDT (6), IOC (5), CH (4), NS (3), ISP (2), ENT (1), C (0)
	; Status Stage
	xor eax, eax
	stosq				; dword 0 & 1 - Reserved Zero
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001013		; TRB Type 4, CH, ENT, C
	stosd				; dword 3 - DIR (16), TRB Type (15:10), IOC (5), CH (4), ENT (1), C (0)
	; Event Data
	add qword [os_usb_evtoken], 1
	mov rax, [os_usb_evtoken]
	push rax
	stosq				; dword 0 & 1 - Data Buffer (63:0)
	xor eax, eax
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001E21		; TRB Type 7, BEI, IOC, C
	stosd				; dword 3 - TRB Type (15:10), BEI (9), IOC (5), CH (4), ENT (1), Cycle (0)

	; Ring the doorbell for current slot
	mov eax, 1			; EPID 1
	xor ecx, ecx
	mov cl, [currentslot]
	call xhci_ring_doorbell

	; Gather result from event ring
	xor eax, eax
	pop rbx				; Restore the token value
	call xhci_check_command_event

	; Check CompCode
	ror rax, 24			; Rotate RAX right by 24 bits to put CompCode in AL
	cmp al, 0x01
	jne xhci_enumerate_devices_end

	; Check TotalLength
	xor ebx, ebx
	mov bx, [os_usb_data0+0x20+2]	; BX contains Configuration Descriptor length

	; Request full data from Configuration Descriptor (includes Interface Descriptor (0x04) / HID Descriptor (0x21))

	; Setup Stage
	mov eax, 0x02000680		; 0x02 Configuration Descriptor
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
	mov eax, 0x00010C01		; DIR, TRB Type 3, C
	stosd				; dword 3 - DIR (16), TRB Type (15:10), IDT (6), IOC (5), CH (4), NS (3), ISP (2), ENT (1), C (0)
	; Status Stage
	xor eax, eax
	stosq				; dword 0 & 1 - Reserved Zero
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001013		; TRB Type 4, CH, ENT, C
	stosd				; dword 3 - DIR (16), TRB Type (15:10), IOC (5), CH (4), ENT (1), C (0)
	; Event Data
	add qword [os_usb_evtoken], 1
	mov rax, [os_usb_evtoken]
	push rax
	stosq				; dword 0 & 1 - Data Buffer (63:0)
	xor eax, eax
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001E21		; TRB Type 7, BEI, IOC, C
	stosd				; dword 3 - TRB Type (15:10), BEI (9), IOC (5), CH (4), ENT (1), Cycle (0)

	; Ring the doorbell for current slot
	mov eax, 1			; EPID 1
	xor ecx, ecx
	mov cl, [currentslot]
	call xhci_ring_doorbell

	; Gather result from event ring
	xor eax, eax
	pop rbx				; Restore the token value
	call xhci_check_command_event

	; Check CompCode
	ror rax, 24			; Rotate RAX right by 24 bits to put CompCode in AL
	cmp al, 0x01
	jne xhci_enumerate_devices_end

	; TODO - Check Configuration Descriptor
	; Example from QEMU keyboard
	;
	; 0000: 0x09 0x02 0x22 0x00 0x01 0x01 0x08 0xA0
	; 0008: 0x32 0x09 0x04 0x00 0x00 0x01 0x03 0x01
	; 0010: 0x01 0x00 0x09 0x21 0x11 0x01 0x00 0x01
	; 0018: 0x22 0x3F 0x00 0x07 0x05 0x81 0x03 0x08
	; 0020: 0x00 0x07
	;
	; Expanded out:
	;
	; Configuration Descriptor
	; 0000: 0x09 0x02 0x22 0x00 0x01 0x01 0x08 0xA0
	; 0008: 0x32
	;
	; Length 0x09
	; Type 0x02
	; Total Length 0x0022
	; Number of Interface 0x01
	; Config Value 0x01
	; Config String 0x08
	; Attributes 0xA0
	; Max Power 0x32
	;
	; Interface Descriptor
	; 0008:      0x09 0x04 0x00 0x00 0x01 0x03 0x01
	; 0010: 0x01 0x00
	;
	; Length 0x09
	; Type 0x04
	; Interface Number 0x00
	; Alternate Set 0x00
	; Endpoints 0x01
	; Class Code 0x03
	; Sub Class 0x01
	; Protocol 0x01 - Keyboard
	; Interface String 0x00
	;
	; HID Descriptor
	; 0010:           0x09 0x21 0x11 0x01 0x00 0x01
	; 0018: 0x22 0x3F 0x00
	;
	; Length 0x09
	; Type 0x21
	; Release 0x0111
	; Contry Code 0x00
	; Number of Descriptor 0x01
	; Desc Type 0x22
	; Desc Length 0x003F
	;
	; Endpoint Descriptor
	; 0018:                0x07 0x05 0x81 0x03 0x08
	; 0020: 0x00 0x07
	;
	; Length 0x07
	; Type 0x05
	; Address 0x81
	; Attributes 0x03
	; Max Packet Size 0x0008
	; Interval 0x07
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

	; Verify that a keyboard was found
	mov rax, os_usb_data0
	add rax, 0x20			; Offset to Configuration Descriptor
	add rax, 14			; Offset to Interface Class Code
	mov eax, [rax]
	and eax, 0x00FFFFFF		; Keep low 3 bytes (discard Interface String)
	cmp eax, 0x00010103		; Look for Class Code 0x03, Sub Class 0x01, and Protocol 0x01
	je foundkeyboard

	; If no keyboard was found at this port then disable the slot and try the next device

	; Disable Slot Command TRB
	; ┌───────────────────────────────────────────────────────────────────────────────────────────────┐
	; |31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00|
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Reserved Zero                                                                                 |
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Reserved Zero                                                                                 |
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Reserved Zero                                                                                 |
	; ├───────────────────────┬───────────────────────┬─────────────────┬──────────────────────────┬──┤
	; | Slot ID               | Reserved Zero         | 10              | Reserved Zero            |C |
	; └───────────────────────┴───────────────────────┴─────────────────┴──────────────────────────┴──┘
	; Ex:
	;	0x00000000 0x00000000 0x00000000 0xXX002801

	; Build a TRB for Disable Slot in the Command Ring
	mov rdi, os_usb_CR
	add rdi, [xhci_croff]
	push rdi
	xor eax, eax
	stosd				; Store dword 0
	stosd				; Store dword 1
	stosd				; Store dword 2
	mov eax, 0x00002801		; Disable Slot - Slot (31:24), xHCI_CTRB_DSLOT (15:10), C (0)
	ror eax, 24
	mov al, [currentslot]
	rol eax, 24
	stosd				; Store dword 3
	add qword [xhci_croff], 16

	; Ring the Doorbell for the Command Ring
	xor eax, eax
	xor ecx, ecx
	call xhci_ring_doorbell

	; Disable Slot Event TRB
	; ┌───────────────────────────────────────────────────────────────────────────────────────────────┐
	; |31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00|
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Address of Disable Slot TRB Lo                                                                |
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Address of Disable Slot TRB Hi                                                                |
	; ├───────────────────────┬───────────────────────────────────────────────────────────────────────┤
	; | CompCode              | Reserved Zero                                                         |
	; ├───────────────────────┴───────────────────────┬─────────────────┬──────────────────────────┬──┤
	; | Slot ID               | Reserved Zero         | 33              | Reserved Zero            |C |
	; └───────────────────────┴───────────────────────┴─────────────────┴──────────────────────────┴──┘
	; Ex:
	;	0xXXXXXXXX 0xXXXXXXXX 0x01000000 0xXX008401

	; Gather result from event ring
	pop rbx				; Restore the Address of the Disable Slot command
	call xhci_check_command_event

	; Check CompCode
	ror rax, 24			; Rotate RAX right by 24 bits to put CompCode in AL
	cmp al, 0x01
	jne xhci_enumerate_devices_end

	; Shift the port list
	push rsi
	push rdi
	xor ecx, ecx
	mov cl, [xhci_portcount]
	mov rdi, xhci_portlist
	mov rsi, rdi
	inc rsi
	rep movsb
	pop rdi
	pop rsi
	dec byte [xhci_portcount]

	jmp xhci_search_devices

foundkeyboard:
	; Send Set Report

	; Setup Stage
	mov eax, 0x00010900		; bRequest 0x09 - Set Report, wValue 0x01
	stosd				; dword 0 - wValue (31:16), bRequest (15:8), bmRequestType (7:0)
	mov eax, 0x00000000
	stosd				; dword 1 - wLength (31:16), wIndex (15:0)
	mov eax, 0x00000008
	stosd				; dword 2 - Interrupter Target (31:22), TRB Transfer Length (16:0)
	mov eax, 0x00000841		; TRT 0, TRB Type 2, IDT, C
	stosd				; dword 3 - TRT (17:16), TRB Type (15:10), IDT (6), IOC (5), C (0)
	; Status Stage
	xor eax, eax
	stosq				; dword 0 & 1 - Reserved Zero
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00011013		; DIR, TRB Type 4, CH, ENT, C
	stosd				; dword 3 - DIR (16), TRB Type (15:10), IOC (5), CH (4), ENT (1), C (0)
	; Event Data
	add qword [os_usb_evtoken], 1
	mov rax, [os_usb_evtoken]
	push rax
	stosq				; dword 0 & 1 - Data Buffer (63:0)
	xor eax, eax
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001E21		; TRB Type 7, BEI, IOC, C
	stosd				; dword 3 - TRB Type (15:10), BEI (9), IOC (5), CH (4), ENT (1), Cycle (0)

	; Ring the doorbell for current slot
	mov eax, 1			; EPID 1
	xor ecx, ecx
	mov cl, [currentslot]
	call xhci_ring_doorbell

	; Gather result from event ring
	xor eax, eax
	pop rbx				; Restore the token value
	call xhci_check_command_event

	; Check CompCode
	ror rax, 24			; Rotate RAX right by 24 bits to put CompCode in AL
	cmp al, 0x01
	jne xhci_enumerate_devices_end

	; Send Set protocol

	; Setup Stage
	mov eax, 0x00000B21		; bRequest 0x0B - Set Protocol, wValue 0x00 - Boot Protocol
	stosd				; dword 0 - wValue (31:16), bRequest (15:8), bmRequestType (7:0)
	mov eax, 0x00000000
	stosd				; dword 1 - wLength (31:16), wIndex (15:0)
	mov eax, 0x00000008
	stosd				; dword 2 - Interrupter Target (31:22), TRB Transfer Length (16:0)
	mov eax, 0x00000841		; TRT 0, TRB Type 2, IDT, C
	stosd				; dword 3 - TRT (17:16), TRB Type (15:10), IDT (6), IOC (5), C (0)
	; Status Stage
	xor eax, eax
	stosq				; dword 0 & 1 - Reserved Zero
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00011013		; DIR, TRB Type 4, CH, ENT, C
	stosd				; dword 3 - DIR (16), TRB Type (15:10), IOC (5), CH (4), ENT (1), C (0)
	; Event Data
	add qword [os_usb_evtoken], 1
	mov rax, [os_usb_evtoken]
	push rax
	stosq				; dword 0 & 1 - Data Buffer (63:0)
	xor eax, eax
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001E21		; TRB Type 7, BEI, IOC, C
	stosd				; dword 3 - TRB Type (15:10), BEI (9), IOC (5), CH (4), ENT (1), Cycle (0)

	; Ring the doorbell for current slot
	mov eax, 1			; EPID 1
	xor ecx, ecx
	mov cl, [currentslot]
	call xhci_ring_doorbell

	; Gather result from event ring
	xor eax, eax
	pop rbx				; Restore the token value
	call xhci_check_command_event

	; Check CompCode
	ror rax, 24			; Rotate RAX right by 24 bits to put CompCode in AL
	cmp al, 0x01
	jne xhci_enumerate_devices_end

	; Send SET_IDLE

	; Setup Stage
	mov eax, 0x00000A21		; bRequest 0x0A - Set Idle
	stosd				; dword 0 - wValue (31:16), bRequest (15:8), bmRequestType (7:0)
	mov eax, 0x00000000
	stosd				; dword 1 - wLength (31:16), wIndex (15:0)
	mov eax, 0x00000008
	stosd				; dword 2 - Interrupter Target (31:22), TRB Transfer Length (16:0)
	mov eax, 0x00000841		; TRT 0, TRB Type 2, IDT, C
	stosd				; dword 3 - TRT (17:16), TRB Type (15:10), IDT (6), IOC (5), C (0)
	; Status Stage
	xor eax, eax
	stosq				; dword 0 & 1 - Reserved Zero
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00011013		; DIR, TRB Type 4, CH, ENT, C
	stosd				; dword 3 - DIR (16), TRB Type (15:10), IOC (5), CH (4), ENT (1), C (0)
	; Event Data
	add qword [os_usb_evtoken], 1
	mov rax, [os_usb_evtoken]
	push rax
	stosq				; dword 0 & 1 - Data Buffer (63:0)
	xor eax, eax
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001E21		; TRB Type 7, BEI, IOC, C
	stosd				; dword 3 - TRB Type (15:10), BEI (9), IOC (5), CH (4), ENT (1), Cycle (0)

	; Ring the doorbell for current slot
	mov eax, 1			; EPID 1
	xor ecx, ecx
	mov cl, [currentslot]
	call xhci_ring_doorbell

	; Gather result from event ring
	xor eax, eax
	pop rbx				; Restore the token value
	call xhci_check_command_event

	; Check CompCode
	ror rax, 24			; Rotate RAX right by 24 bits to put CompCode in AL
	cmp al, 0x01
	jne xhci_enumerate_devices_end

;	; Clear the Input Device Context (Maximum of 2112 bytes)
;	mov rdi, os_usb_IDC
;	xor eax, eax
;	mov ecx, 264			; 2112 bytes / 8
;	rep stosq
;
;	; Copy Device Context to Input Device Context
;	mov rsi, os_usb_DC
;	xor eax, eax
;	mov al, [currentslot]
;	dec al
;	mov ecx, [xhci_csz]
;	shl ecx, 5
;	mul ecx				; EDX:EAX = EAX + ECX
;	add rsi, rax
;	mov rdi, os_usb_IDC
;	mov eax, [xhci_csz]
;	add rdi, rax
;	mov ecx, 256			; 2048 bytes
;	rep movsq

	; Update Input Context
	mov rdi, os_usb_IDC
	; Set Control Context
	mov dword [rdi+4], 0x00000009
	; Set Slot Context
	mov eax, [xhci_csz]
	add rdi, rax
	mov eax, dword [rdi+0]		; Gather dword 0 of the Slot Context
	rol eax, 8
	mov al, 0xF8
	ror eax, 8
	mov dword [rdi+0], eax
	mov dword [rdi+8], 0x00400000	; Set Interrupter Target to 1 (31:22)
	; Set Endpoint Context 0
	mov eax, [xhci_csz]
	add rdi, rax
	; Set Endpoint Context 1 IN
	mov rdi, os_usb_IDC
	mov eax, [xhci_csz]
	add rdi, rax			; Slot
	add rdi, rax			; Control
	add rdi, rax			; EP1 Out
	add rdi, rax			; EP1 In
	mov dword [rdi+4], 0x0008003e	; Set Max Packet Size (31:16) to 8, EP Type (5:3) to 7 (Interrupt IN), CErr (2:1) to 3
	mov rax, os_usb_TR0		; Address of Transfer Ring
	add rax, 0x1000
	bts rax, 0
	mov qword [rdi+8], rax
	mov dword [rdi+16], 0x00080008	; Set Max ESIT Payload (31:16) to 8, Average TRB Length (15:0) to 8

;	; Build a TRB for Evaluate Context in the Command Ring
;	mov rdi, os_usb_CR
;	add rdi, [xhci_croff]
;	push rdi
;	mov rax, os_usb_IDC		; Address of the Input Context
;	stosq				; dword 0 & 1
;	xor eax, eax
;	stosd				; dword 2
;	mov al, [currentslot]
;	shl eax, 24			; Set Slot ID (31:24)
;	mov al, xHCI_CTRB_EVALC
;	shl ax, 10
;	bts eax, 0			; Cycle
;	stosd				; dword 3
;	add qword [xhci_croff], 16
;	; 0xXXXXXXXX 0xXXXXXXXX 0x0000000 0x01003401
;
;	; Ring the Doorbell for the Command Ring
;	xor eax, eax
;	xor ecx, ecx
;	call xhci_ring_doorbell
;
;	; Check result in event ring
;	pop rbx				; Restore the Address of the Enable Slot command
;	call xhci_check_command_event

	; Configure Endpoint Command TRB
	; ┌───────────────────────────────────────────────────────────────────────────────────────────────┐
	; |31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00|
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Address of Input Context Lo                                                                   |
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Address of Input Context Hi                                                                   |
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Reserved Zero                                                                                 |
	; ├───────────────────────┬───────────────────────┬─────────────────┬──────────────────────────┬──┤
	; | Slot ID               | Reserved Zero         | 12              | Reserved Zero            |C |
	; └───────────────────────┴───────────────────────┴─────────────────┴──────────────────────────┴──┘
	; Ex:
	;	0xXXXXXXXX 0xXXXXXXXX 0x0000000 0xXX003001

	; Build a TRB for Configure Endpoint in the Command Ring
	mov rdi, os_usb_CR
	add rdi, [xhci_croff]
	push rdi
	mov rax, os_usb_IDC		; Address of the Input Context
	stosq				; dword 0 & 1
	xor eax, eax
	stosd				; dword 2
	mov al, [currentslot]
	shl eax, 24			; Set Slot ID (31:24)
	mov al, xHCI_CTRB_CONFE
	shl ax, 10
	bts eax, 0			; Cycle
	stosd				; dword 3
	add qword [xhci_croff], 16

	; Ring the Doorbell for the Command Ring
	xor eax, eax
	xor ecx, ecx
	call xhci_ring_doorbell

	; Configure Endpoint Event TRB
	; ┌───────────────────────────────────────────────────────────────────────────────────────────────┐
	; |31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00|
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Address of Configure Endpoint Command TRB Lo                                                  |
	; ├───────────────────────────────────────────────────────────────────────────────────────────────┤
	; | Address of Configure Endpoint Command TRB Hi                                                  |
	; ├───────────────────────┬───────────────────────────────────────────────────────────────────────┤
	; | CompCode              | Reserved Zero                                                         |
	; ├───────────────────────┴───────────────────────┬─────────────────┬──────────────────────────┬──┤
	; | Slot ID               | Reserved Zero         | 33              | Reserved Zero            |C |
	; └───────────────────────┴───────────────────────┴─────────────────┴──────────────────────────┴──┘
	; Ex:
	;	0xXXXXXXXX 0xXXXXXXXX 0x01000000 0xXX008401

	; Gather result from event ring
	pop rbx				; Restore the Address of the Configure Endpoint command
	call xhci_check_command_event

	; Check CompCode
	ror rax, 24			; Rotate RAX right by 24 bits to put CompCode in AL
	cmp al, 0x01
	jne xhci_enumerate_devices_end

	ror rax, 32			; Rotate RAX right by 32 bits to put Slot ID in AL
	mov al, [currentslot]
	mov [keyboardslot], al

	; Prepare Interrupter 1 to read a packet
	mov rdi, os_usb_TR0
	add rdi, 0x1000
	; Normal
	mov rax, os_usb_data0
	add rax, 0x100
	stosq				; dword 0 & 1 - Data Buffer Pointer (63:0)
	mov eax, 0x00000008
	stosd				; dword 2 - Interrupter Target (31:22), TD Size (21:17), TRB Transfer Length (16:0)
	mov eax, 0x00000413		; TRB Type 1, CH, ENT, C
	stosd				; dword 3 - TRB Type (15:10), BEI (9), IDT (6), IOC (5), CH (4), NS (3), ISP (2), ENT (1), C (0)
	; Event Data
	add qword [os_usb_evtoken], 1
	mov rax, [os_usb_evtoken]
	stosq				; dword 0 & 1 - Data Buffer Pointer (63:0)
	mov eax, 0x00400000		; Interrupter Target 1
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001C21		; TRB Type 7, IOC, C
	stosd				; dword 3 - TRB Type (15:10), BEI (9), IOC (5), CH (4), ENT (1), C (0)
	; Ring the doorbell for the Keyboard
	mov eax, 3			; EPID 3
	xor ecx, ecx
	mov cl, [keyboardslot]
	call xhci_ring_doorbell

xhci_enumerate_devices_end:
	pop rax
	pop rbx
	pop rcx
	pop rdx
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; xhci_ring_doorbell - Ring the doorbell for a Slot / EPID
; RCX = Slot
; RAX = EPID
xhci_ring_doorbell:
	push rdi
	push rcx

	mov rdi, [xhci_db]	; Base address for doorbell registers
	shl rcx, 2		; Quick multiply by 4
	add rdi, rcx		; Add offset to slot doorbell
	stosd			; Store EPID

	pop rcx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; xhci_check_command_event - Gather return data for a command
; IN:	RBX = Address of Command / Token
;	RCX = Event ring
; OUT:	RAX = result
; Note:	This command times out after 50,000 microseconds
xhci_check_command_event:
	push rsi
	push rdx
	push rcx
	call os_hpet_us
	mov rdx, rax
	add rdx, 50000		; Add 50,000 μs
	mov rsi, os_usb_ERS	; Event segment for Command Ring
	shl rcx, 12		; Quick multiply by 4096
	add rsi, rcx
load_event:
	call os_hpet_us
	cmp rax, rdx
	ja xhci_check_command_event_timeout
	mov rax, [rsi]
	cmp rax, 0
	jne compare
	sub rsi, 16
	jmp load_event
compare:
	cmp rax, rbx
	je found_event
	add rsi, 16
	jmp load_event
found_event:
	mov rax, [rsi+8]	; Load the result
	pop rcx
	pop rdx
	pop rsi
	ret
xhci_check_command_event_timeout:
	xor eax, eax
	pop rcx
	pop rdx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; xHCI Interrupter 0 - Controller
align 8
xhci_int0:
	push rdi
	push rcx
	push rax

	; Increment counter
	add dword [os_xhci_int0_count], 1

	; Clear Controller Interrupt Pending
	mov rdi, [xhci_op]
	add rdi, xHCI_USBSTS
	mov eax, [rdi]
	btr eax, 3			; Clear Event Interrupt (EINT) (bit 3)
	mov [rdi], eax

	; Clear Interrupter 0 Pending (if set)
	mov rdi, [xhci_rt]
	add rdi, xHCI_IR_0		; Interrupt Register 0
	mov eax, [rdi+xHCI_IR_IMAN]
	btr eax, 0			; Clear Interrupt Pending (IP) (bit 0)
	mov [rdi+xHCI_IR_IMAN], eax

	; Increment dequeue
	mov rax, [rdi+xHCI_IR_ERDP]
	add rax, 16
	mov [rdi+xHCI_IR_ERDP], rax

	; Acknowledge the interrupt
	mov ecx, APIC_EOI
	xor eax, eax
	call os_apic_write

	pop rax
	pop rcx
	pop rdi
	iretq
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; xHCI Interrupter 1 - Keyboard
align 8
xhci_int1:
	push rdi
	push rcx
	push rax

	; Clear Controller Interrupt Pending
	mov rdi, [xhci_op]
	add rdi, xHCI_USBSTS
	mov eax, [rdi]
	btr eax, 3			; Clear Event Interrupt (EINT) (bit 3)
	mov [rdi], eax

	; Get key press
	; 8-byte packet will be at 0x6e0100
	; TODO Logic for shift press
	mov rax, [os_usb_data0+0x100]	; Load 8-byte keyboard packet into RAX
	ror rax, 16
	and eax, 0xFF			; Keep AL only
	mov rdi, usbkeylayoutlower
	add rdi, rax
	mov byte al, [rdi]
	mov [key], al

	; Add TRBs for next interrupt
	mov rdi, os_usb_TR0
	add rdi, 0x1000
	add rdi, [tval]
	; Normal
	mov rax, os_usb_data0
	add rax, 0x100
	stosq				; dword 0 & 1 - Data Buffer Pointer (63:0)
	mov eax, 0x00000008
	stosd				; dword 2 - Interrupter Target (31:22), TD Size (21:17), TRB Transfer Length (16:0)
	mov eax, 0x00000413		; TRB Type 1, CH, ENT, C
	stosd				; dword 3 - TRB Type (15:10), BEI (9), IDT (6), IOC (5), CH (4), NS (3), ISP (2), ENT (1), C (0)
	; Event Data
	add qword [os_usb_evtoken], 1
	mov rax, [os_usb_evtoken]
	stosq				; dword 0 & 1 - Data Buffer Pointer (63:0)
	mov eax, 0x00400000		; Interrupter Target 1
	stosd				; dword 2 - Interrupter Target (31:22)
	mov eax, 0x00001C21		; TRB Type 7, IOC, C
	stosd				; dword 3 - TRB Type (15:10), BEI (9), IOC (5), CH (4), ENT (1), C (0)
	add qword [tval], 32

	; Todo - Check if near the end of the transfer ring. If so, create a link TRB
	; and update Cycle

	; Link
;	mov rax, os_usb_TR0
;	add rax, 0x200
;	stosq				; dword 0 & 1 - Address in Transfer Ring
;	mov eax, 0			; Interrupter Target 0
;	stosd				; dword 2
;	mov eax, 0x00001801		; xHCI_TTRB_LINK (bits 15:10) and Cycle (0)
;	stosd				; dword 3
;	add qword [tval], 16

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

	; Ring the doorbell for the Keyboard
	mov eax, 3			; EPID 3
	xor ecx, ecx
	mov cl, [keyboardslot]
	call xhci_ring_doorbell

	; Acknowledge the interrupt
	mov ecx, APIC_EOI
	xor eax, eax
	call os_apic_write

	pop rax
	pop rcx
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


; Variables
align 16
tval:		dq 32
xhci_op:	dq 0			; Start of Operational Registers
xhci_db:	dq 0			; Start of Doorbell Registers
xhci_rt:	dq 0			; Start of Runtime Registers
xhci_croff:	dq 0
xhci_csz:	dd 32			; Default Context Size
xhci_portlist:	times 32 db 0x00
xhci_portcount:	db 0
currentslot:	db 0
keyboardslot:	db 0
xhci_caplen:	db 0
xhci_maxslots:	db 0
xhci_maxport:	db 0

; xHCI Memory (256K = 0x0 - 0x3FFFF)
os_usb_DCI:		equ os_usb_mem + 0x0		; 2K Device Context Index (256 entries)
os_usb_DC:		equ os_usb_mem + 0x800		; Start of Device Contexts (1024 or 2048 bytes each)
os_usb_CR:		equ os_usb_mem + 0x10000	; 4K Command Ring (16 bytes per entry)
os_usb_ERST:		equ os_usb_mem + 0x18000	; Event Ring Segment Tables
os_usb_ERS:		equ os_usb_mem + 0x20000	; Event Ring Segments
os_usb_IDC:		equ os_usb_mem + 0x2F000	; 4K Temporary Input Device Context (temporary buffer of max 64+2048 bytes)
os_usb_TR0:		equ os_usb_mem + 0x30000	; Temp transfer ring
os_usb_data0:		equ os_usb_mem + 0x38000	; Temp data
os_usb_scratchpad:	equ os_usb_mem + 0x3B000	; 4K Index and 4x 4K Scratchpad entries


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
xHCI_SET_ADDRESS	equ 0x05
xHCI_GET_DESCRIPTOR	equ 0x06
xHCI_SET_DESCRIPTOR	equ 0x07
xHCI_GET_CONFIGURATION	equ 0x08
xHCI_SET_CONFIGURATION	equ 0x09
xHCI_GET_INTERFACE	equ 0x0A
xHCI_SET_INTERFACE	equ 0x0B

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
db 0, 1, 2, 3, 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', 0x1C, 41, 0x0E, 43, ' ', '-', '=', '[', ']', "\", 50, ';', "'", '`', ',', '.', '/', 57
usbkeylayoutupper:
db 0, 1, 2, 3, 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', 0x1C, 41, 0x0E, 43, ' ', '_', '+', '{', '}', '|', 50, ':', '"', '~', '<', '>', '?', 57
; 0e = backspace
; 1c = enter


; =============================================================================
; EOF