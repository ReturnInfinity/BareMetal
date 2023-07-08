; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2023 Return Infinity -- see LICENSE.TXT
;
; AHCI Driver
; =============================================================================


; -----------------------------------------------------------------------------
ahci_init:
	push rsi			; Used in init_storage
	push rdx			; EDX should already point to a supported device for os_pci_read/write

	cmp byte [os_AHCIEnabled], 1	; TODO - support multiple AHCI controllers
	je ahci_init_error

	mov dl, 9			; Read register 9 for BAR5
	xor eax, eax
	call os_pci_read		; BAR5 (AHCI Base Address Register)
	and eax, 0xFFFFFFF0		; Clear the lowest 4 bits
	mov [ahci_base], rax
	mov rsi, rax			; RSI holds the ABAR

	; Mark memory as uncacheable
	; TODO cleanup to do it automatically (for NVMe too!)
;	mov rdi, 0x00013fa8
;	mov rax, [rdi]
;	bts rax, 4	; Set PCD to disable caching
;	mov [rdi], rax

	; Check for a valid version number (Bits 31:16 should be greater than 0)
	mov eax, [rsi+AHCI_VS]
	ror eax, 16			; Rotate EAX so MJR is bits 15:00
	cmp al, 0x01
	jl ahci_init_error
	mov [os_AHCIMJR], al
	rol eax, 8			; Rotate EAX so MNR is bits 07:00
	mov [os_AHCIMNR], al

	; Grab the IRQ of the device
	mov dl, 0x0F			; Get device's IRQ number from PCI Register 15 (IRQ is bits 7-0)
	call os_pci_read
	mov [os_AHCIIRQ], al		; AL holds the IRQ

	; Enable AHCI
	xor eax, eax
	bts eax, 31
	mov [rsi+AHCI_GHC], eax

	; Search the implemented ports for connected devices
	mov edx, [rsi+AHCI_PI]		; PI – Ports Implemented
	xor ecx, ecx
ahci_init_search_ports:
	cmp ecx, 32			; Maximum number of AHCI ports
	je ahci_init_search_ports_done
	bt edx, ecx			; Is this port marked as implemented?
	jnc ahci_init_skip_port		; If not, skip it

	mov ebx, ecx			; Copy current port
	shl ebx, 7			; Multiply by 128 (0x80) for start of port registers
	add ebx, 0x128			; Add 0x100 port registers and 0x28 for PxSSTS

	mov eax, [rsi+rbx]
	and al, 0x0F			; Keep bits 3-0
	cmp al, 0x03			; Check if device is present and comm enabled
	jne ahci_init_skip_port		; If not skip the port

	bts dword [ahci_PA], ecx	; Set the port # as active

ahci_init_skip_port:
	inc rcx
	jmp ahci_init_search_ports

ahci_init_search_ports_done:

	; Configure the active ports
	mov edx, [ahci_PA]
	xor ecx, ecx
ahci_init_config_active:
	cmp ecx, 32			; Maximum number of AHCI ports
	je ahci_init_done
	bt edx, ecx			; Is this port marked as active?
	jnc ahci_init_config_active_skip

	mov rdi, rsi			; RSI holds the AHCI Base address
	add rdi, 0x100			; Offset to port 0
	shl rcx, 7			; Quick multiply by 0x80
	add rdi, rcx
	shr rcx, 7

	mov eax, [rdi+AHCI_PxCMD]	; Stop the port
	btr eax, 4			; FRE
	btr eax, 0			; ST
	mov [rdi+AHCI_PxCMD], eax

	xor eax, eax
	mov [rdi+AHCI_PxCI], eax	; Clear all command slots

	mov rax, ahci_CLB		; Command List (1K with 32 entries, 32 bytes each)
	shl rcx, 10
	add rax, rcx			; Add offset to base
	shr rcx, 10
	stosd				; Offset 00h: PxCLB – Port x Command List Base Address
	shr rax, 32			; 63..32 bits of address
	stosd				; Offset 04h: PxCLBU – Port x Command List Base Address Upper 32-bits

	mov rax, ahci_FB		; Received FIS (4096 bytes per port)
	shl rcx, 12
	add rax, rcx			; Add offset to base
	shr rcx, 12
	stosd				; Offset 08h: PxFB – Port x FIS Base Address
	shr rax, 32			; 63..32 bits of address
	stosd				; Offset 0Ch: PxFBU – Port x FIS Base Address Upper 32-bits

	xor eax, eax
	stosd				; Offset 10h: PxIS – Port x Interrupt Status
	stosd				; Offset 14h: PxIE – Port x Interrupt Enable

ahci_init_config_active_skip:
	inc rcx
	jmp ahci_init_config_active
	
ahci_init_done:
	mov byte [os_AHCIEnabled], 1	; Set the flag that AHCI has been initialized
	pop rdx
	pop rsi
	add rsi, 15
	mov byte [rsi], 1		; Mark driver as installed in PCI Table
	sub rsi, 15
	ret

ahci_init_error:
	pop rdx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; ahci_io -- Perform an I/O operation on an AHCI device
; IN:	RAX = starting sector # (48-bit LBA address)
;	RBX = I/O Opcode
;	RCX = number of sectors
;	RDX = drive #
;	RDI = memory location
; OUT:	Nothing
;	All other registers preserved
ahci_io:
	push rdx
	push rbx
	push rdi
	push rsi
	push rcx
	push rax

	shl rax, 3			; Convert to 512B starting sector
	shl rcx, 3			; Convert 4K sectors to 512B sectors

	bt dword [ahci_PA], edx		; Is the requested device marked as active?
	jnc achi_io_error		; If not, bail out
	
	cmp rcx, 8192			; Are we trying to read more that 4MiB?
	jge achi_io_error		; If so, bail out

	push rcx			; Save the sector count
	push rdi			; Save the destination memory address
	push rax			; Save the block number
	push rax

	mov rsi, [ahci_base]
	push rdx
	shl rdx, 7			; Quick multiply by 0x80
	add rdx, 0x100			; Offset to port 0
	add rsi, rdx
	pop rdx

	; Build the Command List Header
	mov rdi, ahci_CLB		; Command List (1K with 32 entries, 32 bytes each)
	shl rdx, 10
	add rdi, rdx
	shr rdx, 10
	mov eax, 0x00010005		; 1 PRDTL Entry, Command FIS Length = 20 bytes
	cmp ebx, 0x35			; Was a write requested?
	jne ahci_io_skip_writebit	; If not, skip setting the write flag
	bts ebx, 6			; Set the write flag (bit 6)
ahci_io_skip_writebit:
	stosd				; DW 0 - Description Information
	xor eax, eax
	stosd				; DW 1 - Command Status
	mov eax, ahci_CMD
	stosd				; DW 2 - Command Table Base Address
	shr rax, 32			; 63..32 bits of address
	stosd				; DW 3 - Command Table Base Address Upper
	xor eax, eax
	stosq				; DW 4 - 7 are reserved
	stosq

	; Build the Command Table
	mov rdi, ahci_CMD		; Build a command table for Port 0
	mov eax, ebx
	shl eax, 16			; Shift command to bits 31:16
	add eax, 0x8027			; bit 15 set, FIS 27 H2D
	stosd				; feature 7:0, command, c, FIS
	pop rax				; Restore the start sector number
	shl rax, 36
	shr rax, 36			; Upper 36 bits cleared
	bts rax, 30			; bit 30 set for LBA
	stosd				; device, LBA 23:16, LBA 15:8, LBA 7:0
	pop rax				; Restore the start sector number
	shr rax, 24
	stosd				; feature 15:8, LBA 47:40, LBA 39:32, LBA 31:24
	mov rax, rcx			; Read the number of sectors given in rcx
	stosd				; control, ICC, count 15:8, count 7:0
	xor eax, eax
	stosd				; reserved

	; PRDT setup
	mov rdi, ahci_CMD + 0x80
	pop rax				; Restore the destination memory address
	stosd				; Data Base Address
	shr rax, 32
	stosd				; Data Base Address Upper
	xor eax, eax
	stosd				; Reserved
	pop rax				; Restore the sector count
	shl rax, 9			; multiply by 512 for bytes
	dec rax				; subtract 1 (4.2.3.3, DBC is number of bytes - 1)
	stosd				; Description Information (DBC is 21:00)

	xor eax, eax
	mov [rsi+AHCI_PxIS], eax	; Port x Interrupt Status

	mov eax, 0x00000001		; Execute Command Slot 0
	mov [rsi+AHCI_PxCI], eax

	xor eax, eax
	bts eax, 4			; FIS Receive Enable (FRE)
	bts eax, 0			; Start (ST)
	mov [rsi+AHCI_PxCMD], eax	; Offset to port 0 Command and Status

ahci_io_poll:
	mov eax, [rsi+AHCI_PxCI]
	test eax, eax
	jnz ahci_io_poll

	mov eax, [rsi+AHCI_PxCMD]	; Offset to port 0
	btr eax, 4			; FIS Receive Enable (FRE)
	btr eax, 0			; Start (ST)
	mov [rsi+AHCI_PxCMD], eax

	pop rax				; rax = start
	pop rcx				; rcx = number of sectors read
	add rax, rcx			; rax = start + number of sectors read
	pop rsi
	pop rdi
	mov rbx, rcx			; rdi = dest addr + number of bytes read
	shl rbx, 9
	add rdi, rbx
	pop rbx
	pop rdx
	ret

achi_io_error:
	pop rax				; rax = start
	pop rcx				; rcx = number of sectors read
	pop rsi
	pop rdi
	pop rbx
	pop rdx
	xor ecx, ecx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; ahci_id -- Identify a SATA drive
; IN:	RDX = Port # to query
;	RDI = memory location to store details (512 bytes)
; OUT:	Nothing, all registers preserved
ahci_id:
	push rdi
	push rsi
	push rdx
	push rax
	push rdi			; Save the destination memory address

	bt dword [ahci_PA], edx		; Is the requested drive marked as active?
	jnc ahci_id_error		; If not, bail out

	mov rsi, [ahci_base]
	push rdx
	shl rdx, 7			; Quick multiply by 0x80
	add rdx, 0x100			; Offset to port 0
	add rsi, rdx
	pop rdx

	; Build the Command List Header
	mov rdi, ahci_CLB		; Command List (1K with 32 entries, 32 bytes each)
	shl rdx, 10
	add rdi, rdx
	shr rdx, 10
	mov eax, 0x00010005		; 1 PRDTL Entry, Command FIS Length = 20 bytes
	stosd				; DW 0 - Description Information
	xor eax, eax
	stosd				; DW 1 - Command Status
	mov rax, ahci_CMD
	stosd				; DW 2 - Command Table Base Address
	shr rax, 32			; 63..32 bits of address
	stosd				; DW 3 - Command Table Base Address Upper
	xor eax, eax
	stosq				; DW 4 - 7 are reserved
	stosq

	; Build the Command Table
	mov rdi, ahci_CMD		; Build a command table for Port 0
	mov eax, 0x00EC8027		; EC identify, bit 15 set, FIS 27 H2D
	stosd				; feature 7:0, command, c, FIS
	xor eax, eax
	stosq				; the rest of the table can be clear
	stosq

	; PRDT - physical region descriptor table
	mov rdi, ahci_CMD + 0x80
	pop rax				; Restore the destination memory address
	stosd				; Data Base Address
	shr rax, 32
	stosd				; Data Base Address Upper
	xor eax, eax
	stosd				; Reserved
	mov eax, 0x000001FF		; 512 - 1
	stosd				; Description Information

	xor eax, eax
	mov [rsi+AHCI_PxIS], eax	; Port x Interrupt Status

	mov eax, 0x00000001		; Execute Command Slot 0
	mov [rsi+AHCI_PxCI], eax

	xor eax, eax
	bts eax, 4			; FIS Receive Enable (FRE)
	bts eax, 0			; Start (ST)
	mov [rsi+AHCI_PxCMD], eax	; Offset to port 0 Command and Status

ahci_id_poll:
	mov eax, [rsi+AHCI_PxCI]	; Read Command Slot 0 status
	test eax, eax
	jnz ahci_id_poll

	mov eax, [rsi+AHCI_PxCMD]	; Offset to port 0
	btr eax, 4			; FIS Receive Enable (FRE)
	btr eax, 0			; Start (ST)
	mov [rsi+AHCI_PxCMD], eax

	pop rax
	pop rdx
	pop rsi
	pop rdi
	ret

ahci_id_error:
	pop rdi
	pop rax
	pop rdx
	pop rsi
	pop rdi
	mov eax, 0xFFFFFFFF
	ret
; -----------------------------------------------------------------------------


; HBA Memory Registers
; 0x0000 - 0x002B	Generic Host Control
; 0x002C - 0x005F	Reserved
; 0x0060 - 0x009F	Reserved for NVMHCI
; 0x00A0 - 0x00FF	Vendor Specific Registers
; 0x0100 - 0x017F	Port 0
; 0x0180 - 0x01FF	Port 1
; ...
; 0x1000 - 0x107F	Port 30
; 0x1080 - 0x10FF	Port 31

; Generic Host Control
AHCI_CAP		equ 0x0000 ; HBA Capabilities
AHCI_GHC		equ 0x0004 ; Global HBA Control
AHCI_IS			equ 0x0008 ; Interrupt Status Register
AHCI_PI			equ 0x000C ; Ports Implemented
AHCI_VS			equ 0x0010 ; AHCI Version
AHCI_CCC_CTL		equ 0x0014 ; Command Completion Coalescing Control
AHCI_CCC_PORTS		equ 0x0018 ; Command Completion Coalescing Ports
AHCI_EM_LOC		equ 0x001C ; Enclosure Management Location
AHCI_EM_CTL		equ 0x0020 ; Enclosure Management Control
AHCI_CAP2		equ 0x0024 ; HBA Capabilities Extended
AHCI_BOHC		equ 0x0028 ; BIOS/OS Handoff Control and Status

; Port Registers
; Port 0 starts at 100h, port 1 starts at 180h, port 2 starts at 200h, port 3 at 280h, etc.
AHCI_PxCLB		equ 0x0000 ; Port x Command List Base Address
AHCI_PxCLBU		equ 0x0004 ; Port x Command List Base Address Upper 32-bits
AHCI_PxFB		equ 0x0008 ; Port x FIS Base Address
AHCI_PxFBU		equ 0x000C ; Port x FIS Base Address Upper 32-bits
AHCI_PxIS		equ 0x0010 ; Port x Interrupt Status
AHCI_PxIE		equ 0x0014 ; Port x Interrupt Enable
AHCI_PxCMD		equ 0x0018 ; Port x Command and Status
AHCI_PxTFD		equ 0x0020 ; Port x Task File Data
AHCI_PxSIG		equ 0x0024 ; Port x Signature
AHCI_PxSSTS		equ 0x0028 ; Port x Serial ATA Status (SCR0: SStatus)
AHCI_PxSCTL		equ 0x002C ; Port x Serial ATA Control (SCR2: SControl)
AHCI_PxSERR		equ 0x0030 ; Port x Serial ATA Error (SCR1: SError)
AHCI_PxSACT		equ 0x0034 ; Port x Serial ATA Active (SCR3: SActive)
AHCI_PxCI		equ 0x0038 ; Port x Command Issue
AHCI_PxSNTF		equ 0x003C ; Port x Serial ATA Notification (SCR4: SNotification)
AHCI_PxFBS		equ 0x0040 ; Port x FIS-based Switching Control
AHCI_PxDEVSLP		equ 0x0044 ; Port x Device Sleep
; 0x0048 - 0x006F	Reserved
; 0x0070 - 0x007F	Port x Vendor Specific

; Opcodes for AHCI Commands
AHCI_Write		equ 0x35
AHCI_Read		equ 0x25
AHCI_Identify		equ 0xEC


; =============================================================================
; EOF
