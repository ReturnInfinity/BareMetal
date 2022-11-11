; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2020 Return Infinity -- see LICENSE.TXT
;
; NVMe Driver
; =============================================================================


; -----------------------------------------------------------------------------
nvme_init:
	; Probe for an NVMe controller
	mov edx, 0x00000002		; Start at register 2 of the first device

nvme_init_probe_next:
	call os_pci_read
	shr eax, 16			; Move the Class/Subclass code to AX
	cmp ax, 0x0108			; Mass Storage Controller (01) / NVMe Controller (08)
	je nvme_init_found		; Found a NVMe Controller
	add edx, 0x00000100		; Skip to next PCI device
	cmp edx, 0x00FFFF00		; Maximum of 65536 devices
	jge nvme_init_not_found
	jmp nvme_init_probe_next

nvme_init_found:
	mov dl, 4			; Read register 4 for BAR0
	xor eax, eax
	call os_pci_read		; BAR0 (NVMe Base Address Register)
	and eax, 0xFFFFFFF0		; Clear the lowest 4 bits
	mov [os_NVMe_Base], rax
	mov rsi, rax			; RSI holds the ABAR

	; Mark memory as uncacheable
	; TODO cleanup to do it automatically (for AHCI too!)
;	mov rdi, 0x00013fa8
;	mov rax, [rdi]
;	bts rax, 4	; Set PCD to disable caching
;	mov [rdi], rax

	; Check for a valid version number (Bits 31:16 should be greater than 0)
	mov eax, [rsi+NVMe_VS]
	ror eax, 16			; Rotate EAX so MJR is bits 15:00
	cmp al, 0x01
	jl nvme_init_not_found
	mov [os_NVMeMJR], al
	rol eax, 8			; Rotate EAX so MNR is bits 07:00
	mov [os_NVMeMNR], al
	rol eax, 8			; Rotate EAX so TER is bits 07:00
	mov [os_NVMeTER], al

	; Grab the IRQ of the device
	mov dl, 0x0F			; Get device's IRQ number from PCI Register 15 (IRQ is bits 7-0)
	call os_pci_read
	mov [os_NVMeIRQ], al		; AL holds the IRQ

	; Enable PCI Bus Mastering
	mov dl, 0x01			; Get Status/Command
	call os_pci_read
	bts eax, 2
	call os_pci_write

	; Clear 64 KiB of memory for NVMe structures
	mov edi, nvme_base
	mov ecx, 8192
	xor eax, eax
	rep stosq

	; Disable the controller
	mov eax, [rsi+NVMe_CC]
	btc eax, 0			; Set CC.EN to '0'
	mov [rsi+NVMe_CC], eax

	; Reset the controller (if allowed)
	mov rax, [rsi+NVMe_CAP]
	bt rax, 58			; CAP.NSSS
	jnc nvme_init_reset_wait
	mov eax, 0x4E564D65		; String is "NVMe"
	mov [rsi+NVMe_NSSR], eax	; Reset

nvme_init_reset_wait:
	mov eax, [rsi+NVMe_CSTS]
	bt eax, 0			; Wait for CSTS.RDY to become '0'
	jc nvme_init_reset_wait

	; Configure AQA, ASQ, and ACQ
	mov eax, 0x003F003F		; 64 commands each for ACQS (27:16) and ASQS (11:00)
	mov [rsi+NVMe_AQA], eax
	mov rax, nvme_asqb		; ASQB (63:12)
	mov [rsi+NVMe_ASQ], rax
	mov rax, nvme_acqb		; ACQB (63:12)
	mov [rsi+NVMe_ACQ], rax

	mov eax, 0xFFFFFFFF		; Mask all interrupts
	mov [rsi+NVMe_INTMS], eax

	; Enable the controller
	mov eax, 0x00460001		; Set IOCQES (23:20), IOSQES (19:16), and EN (0)
	mov [rsi+NVMe_CC], eax		; Write the new CC value and enable controller
	
nvme_init_enable_wait:
	mov eax, [rsi+NVMe_CSTS]
	bt eax, 0			; Wait for CSTS.RDY to become '1'
	jnc nvme_init_enable_wait

	; Get the Identify Controller structure
	mov rdi, nvme_asqb		; Build the following commands directly in the Admin Submission Queue
	mov eax, 0x00000006		; CDW0 CID 0, PRP used (15:14 clear), FUSE normal (bits 9:8 clear), command Identify (0x06)
	stosd
	xor eax, eax
	stosd				; CDW1 NSID cleared
	stosd				; CDW2
	stosd				; CDW3
	stosq				; CDW4-5 MPTR	
	mov rax, nvme_identity
	stosq				; CDW6-7 DPTR1
	xor eax, eax
	stosq				; CDW8-9 DPTR2
	mov eax, 1
	stosd				; CDW10 CNS 1 (Identify Controller)
	xor eax, eax
	stosd				; CDW11
	stosd				; CDW12
	stosd				; CDW13
	stosd				; CDW14
	stosd				; CDW15

	; Get the Active Namespace ID list
	mov eax, 0x00000006		; CDW0 CID 0, PRP used (15:14 clear), FUSE normal (bits 9:8 clear), command Identify (0x06)
	stosd
	xor eax, eax
	stosd				; CDW1 NSID cleared
	stosd				; CDW2
	stosd				; CDW3
	stosq				; CDW4-5 MPTR	
	mov rax, nvme_activenamespace
	stosq				; CDW6-7 DPTR1
	xor eax, eax
	stosq				; CDW8-9 DPTR2
	mov eax, 2
	stosd				; CDW10 CNS 2 (Active Namespace)
	xor eax, eax
	stosd				; CDW11
	stosd				; CDW12
	stosd				; CDW13
	stosd				; CDW14
	stosd				; CDW15

	; Get the Identify Namespace structure
	mov eax, 0x00000006		; CDW0 CID 0, PRP used (15:14 clear), FUSE normal (bits 9:8 clear), command Identify (0x06)
	stosd
	mov eax, 1
	stosd				; CDW1 NSID
	xor eax, eax
	stosd				; CDW2
	stosd				; CDW3
	stosq				; CDW4-5 MPTR	
	mov rax, nvme_identitynamespace
	stosq				; CDW6-7 DPTR1
	xor eax, eax
	stosq				; CDW8-9 DPTR2
	mov eax, 0
	stosd				; CDW10 CNS 2 (Identify Namespace)
	xor eax, eax
	stosd				; CDW11
	stosd				; CDW12
	stosd				; CDW13
	stosd				; CDW14
	stosd				; CDW15

	; Create I/O Completion Queue
	mov eax, 0x00010005		; CDW0 CID (31:16), PRP used (15:14 clear), FUSE normal (bits 9:8 clear), command Create I/O Completion Queue (0x05)
	stosd
	xor eax, eax
	stosd				; CDW1 NSID cleared
	stosd				; CDW2
	stosd				; CDW3
	stosq				; CDW4-5 MPTR	
	mov rax, nvme_iocqb
	stosq				; CDW6-7 DPTR1
	xor eax, eax
	stosq				; CDW8-9 DPTR2
	mov eax, 0x003F0001
	stosd				; CDW10 QSIZE (31-16), QID (15-0)
	mov eax, 1
	stosd				; CDW11 PC (0)
	xor eax, eax
	stosd				; CDW12
	stosd				; CDW13
	stosd				; CDW14
	stosd				; CDW15

	; Create I/O Submission Queue
	mov eax, 0x00010001		; CDW0 CID (31:16), PRP used (15:14 clear), FUSE normal (bits 9:8 clear), command Create I/O Submission Queue (0x01)
	stosd
	xor eax, eax
	stosd				; CDW1 NSID cleared
	stosd				; CDW2
	stosd				; CDW3
	stosq				; CDW4-5 MPTR	
	mov rax, nvme_iosqb
	stosq				; CDW6-7 DPTR1
	xor eax, eax
	stosq				; CDW8-9 DPTR2
	mov eax, 0x003F0001
	stosd				; CDW10 QSIZE (31-16), QID (15-0)
	mov eax, 0x00010001
	stosd				; CDW11 CQID (31-16), PC (0)
	xor eax, eax
	stosd				; CDW12
	stosd				; CDW13
	stosd				; CDW14
	stosd				; CDW15

	; Start the Admin commands
	mov eax, 0
	mov [rsi+0x1004], eax		; Write the head
	mov eax, 5
	mov [rsi+0x1000], eax		; Write the tail
	mov [os_NVMe_atail], al

nvme_init_admin_wait:
	; TODO Calculate the offset properly
	; First two dwords are command specific
	; DW2 - SQ Identifier (SQID) bits 31:16, SQ Head Pointer (SQHD) bits 15:00
	; DW3 - Status bits 31:17, Phase bit 16, Command Identifier (CID) bits 15:00
	mov eax, [nvme_acqb + 0x48]
	cmp eax, 0x0
	je nvme_init_admin_wait

	; Parse the Controller Identify data
	; Serial Number (SN) bytes 23-04
	; Model Number (MN) bytes 63-24
	; Firmware Revision (FR) bytes 71-64
	; Maximum Data Transfer Size (MDTS) byte 77
	; Controller ID (CNTLID) bytes 79-78
	mov rsi, nvme_identity
	add rsi, 77
	lodsb
	; The value is in units of the minimum memory page size (CAP.MPSMIN) and is reported as a power of two (2^n).
	; A value of 0h indicates that there is no maximum data transfer size.
	; NVMe_CAP Memory Page Size Maximum (MPSMAX): bits 55:52 - The maximum memory page size is (2 ^ (12 + MPSMAX))
	; NVMe_CAP Memory Page Size Minimum (MPSMIN): bits 51:48 - The minimum memory page size is (2 ^ (12 + MPSMIN))
	; NVMe_CC Memory Page Size (MPS) bits 10:07 - The memory page size is (2 ^ (12 + MPS)). Min 4 KiB, max 128 MiB
	; TODO verify MPS is set within allowed bounds. CC.EN to 0 before changing

	; TODO move this to it's own function
	; Parse the Namespace Identify data for disk 0
	mov rsi, nvme_identitynamespace
	lodsd				; Namespace Size (NSZE) bytes 07-00 - Total LBA blocks
	mov [os_NVMeTotalLBA], eax

	; Number of LBA Formats (NLBAF) byte 25
	; 0 means only one format is supported. Located at bytes 131:128
	; LBA Data Size (LBADS) is bits 23:16. Needs to be 9 or greater
	; 9 = 512 byte sectors
	; 12 = 4096 byte sectors
	mov ecx, [nvme_identitynamespace+24]
	shr ecx, 16
	add cl, 1			; NLBAF is a 0-based number
	mov rsi, nvme_identitynamespace+0x80
	xor ebx, ebx
nvme_init_LBA_next:
	cmp cl, 0			; Check # of formats
	je nvme_init_LBA_end
	lodsd				; RP (25:24), LBADS (23:16), MS (15:00)
	shr eax, 16			; AL holds the LBADS
	mov bl, al			; BL holds the highest LBADS so far
	cmp al, bl
	jle nvme_init_LBA_skip
	mov bl, al			; BL holds the highest LBADS so far
nvme_init_LBA_skip:
	dec cl
	jmp nvme_init_LBA_next
nvme_init_LBA_end:
	mov [os_NVMeLBA], bl		; Store the highest LBADS

	; Set the IO head and tail
	mov rdi, [os_NVMe_Base]
	mov eax, 0
	mov [rdi+0x100C], eax		; Write the head
	mov [rdi+0x1008], eax		; Write the tail	

	; Execute a test read
	mov rax, 1			; Starting sector
	mov rcx, 16			; Num of sectors
	mov rdx, 1			; Disk num
	mov rdi, 0x800000		; memory location
	call nvme_read			; Test read

	; Execute another test read
	mov rax, 4			; Starting sector
	mov rcx, 4			; Num of sectors
	mov rdx, 1			; Disk num
	mov rdi, 0x810000		; memory location
	call nvme_read			; Test read

nvme_init_not_found:
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; nvme_read -- Read data from a NVMe device
; IN:	RAX = starting sector # to read (48-bit LBA address)
;	RCX = number of sectors to read (up to 8192 = 4MiB)
;	RDX = disk #
;	RDI = memory location to store data
; OUT:	Nothing
;	All other registers preserved
nvme_read:
	push rdi
	push rcx
	push rbx

	push rax			; Save the starting sector
	mov rbx, rdi			; Save the memory location

	cmp rcx, 0			; Error if no data was requested
	je nvme_read_error

	; Check sector size
	; TODO This needs to check based on the Namespace ID
	mov al, [os_NVMeLBA]
	cmp al, 0x0C			; 4096B sectors
	je nvme_read_setup
	cmp al, 0x09			; 512B sectors
	jne nvme_read_error

	; Convert sector sizes if needed
nvme_read_512b:
	shl rcx, 3			; Covert count to 4096B sectors
	pop rax
	shl rax, 3			; Convert starting sector to 4096B sectors
	push rax

	; Create I/O Entry
nvme_read_setup:
	; Build the command at the expected location in the Submission ring
	mov rdi, nvme_iosqb
	xor eax, eax
	mov al, [os_NVMe_iotail]	; Get the current I/O tail value
	shl eax, 6
	add rdi, rax

	; Create the 64-byte command
	mov eax, 0x00000002		; CDW0 CID (31:16), PRP used (15:14 clear), FUSE normal (bits 9:8 clear), command Read (0x02)
	stosd
	mov eax, edx			; Move the Namespace ID to RAX
	stosd				; CDW1 NSID
	xor eax, eax
	stosq				; CDW2-3 ELBST EILBRT (47:00)
	stosq				; CDW4-5 MPTR
	mov rax, rbx			; Move the memory address to RAX
	stosq				; CDW6-7 PRP1
	
	; Calculate PRP2
	push rcx			; Save the requested sector count for later
	cmp rcx, 2
	jle nvme_read_calc_rpr2_skip
	sub rcx, 1			; Subtract one as PTR1 covers one 4K load
	push rdi
	mov rdi, nvme_rpr		; Space to build the RPR2 structure
nvme_read_next_rpr:
	add rax, 4096			; An entry is needed for every 4K
	stosq
	sub rcx, 1
	cmp rcx, 0
	jne nvme_read_next_rpr	
	pop rdi
	mov rax, nvme_rpr
	jmp nvme_read_calc_rpr2_end	; Write the address of the RPR2 data
nvme_read_calc_rpr2_skip:
	add rax, 4096
nvme_read_calc_rpr2_end:	
	stosq				; CDW8-9 PRP2
	pop rcx				; Restore the sector count

	pop rax				; Restore the starting sector
	stosd				; CDW10 SLBA (31:00)
	shr rax, 32
	stosd				; CDW11 SLBA (63:32)
	mov eax, ecx
	sub eax, 1
	stosd				; CDW12 Number of Logical Blocks (15:00)
	xor eax, eax
	stosd				; CDW13 DSM (07:00)
	stosd				; CDW14 ELBST EILBRT (31:00)
	stosd				; CDW15 ELBATM (31:16), ELBAT (15:00)

	; Start the I/O command by updating the tail doorbell
	mov rdi, [os_NVMe_Base]
	xor eax, eax
	mov al, [os_NVMe_iotail]	; Get the current I/O tail value
	mov ecx, eax			; Save the old I/O tail value for reading from the completion ring
	add al, 1			; Add 1 to it
	cmp al, 64			; Is it 64 or greater?
	jl nvme_read_savetail
	xor eax, eax			; Is so, wrap around to 0
nvme_read_savetail:
	mov [os_NVMe_iotail], al	; Save the tail for the next command
	mov [rdi+0x1008], eax		; Write the new tail value
	
	; Check completion queue
	mov rdi, nvme_iocqb
	shl rcx, 4			; Each entry is 16 bytes
	add rcx, 8			; Add 8 for DW3
	add rdi, rcx
nvme_read_wait:
	mov eax, [rdi]
	cmp eax, 0x0
	je nvme_read_wait
	xor eax, eax
	stosd				; Overwrite the old entry

nvme_read_error:
	pop rbx
	pop rcx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; nvme_write -- Write data to a NVMe device
; IN:	
; OUT:	
nvme_write:
	ret
; -----------------------------------------------------------------------------

; Register list
NVMe_CAP		equ 0x00 ; Controller Capabilities
NVMe_VS			equ 0x08 ; Version
NVMe_INTMS		equ 0x0C ; Interrupt Mask Set
NVMe_INTMC		equ 0x10 ; Interrupt Mask Clear
NVMe_CC			equ 0x14 ; Controller Configuration
NVMe_CSTS		equ 0x1C ; Controller Status
NVMe_NSSR		equ 0x20 ; NSSR – NVM Subsystem Reset
NVMe_AQA		equ 0x24 ; Admin Queue Attributes
NVMe_ASQ		equ 0x28 ; Admin Submission Queue Base Address
NVMe_ACQ		equ 0x30 ; Admin Completion Queue Base Address
NVMe_CMBLOC		equ 0x38 ; Controller Memory Buffer Location
NVMe_CMBSZ		equ 0x3C ; Controller Memory Buffer Size
NVMe_BPINFO		equ 0x40 ; Boot Partition Information
NVMe_BPRSEL		equ 0x44 ; Boot Partition Read Select
NVMe_BPMBL		equ 0x48 ; Boot Partition Memory Buffer Location
NVMe_CMBMSC		equ 0x50 ; Controller Memory Buffer Memory Space Control
NVMe_CMBSTS		equ 0x58 ; Controller Memory Buffer Status
NVMe_CMBEBS		equ 0x5C ; Controller Memory Buffer Elasticity Buffer Size
NVMe_CMBSWTP		equ 0x60 ; Controller Memory Buffer Sustained Write Throughput
NVMe_NSSD		equ 0x64 ; NVM Subsystem Shutdown
NVMe_CRTO		equ 0x68 ; Controller Ready Timeouts

NVMe_PMRCAP		equ 0xE00 ; Persistent Memory Region Capabilities
NVMe_PMRCTL		equ 0xE04 ; Persistent Memory Region Control
NVMe_PMRSTS		equ 0xE08 ; Persistent Memory Region Status
NVMe_PMREBS		equ 0xE0C ; Persistent Memory Region Elasticity Buffer Size
NVMe_PMRSWTP		equ 0xE10 ; Persistent Memory Region Sustained Write Throughput 
NVMe_PMRMSCL		equ 0xE14 ; Persistent Memory Region Memory Space Control Lower
NVMe_PMRMSCU		equ 0xE18 ; Persistent Memory Region Memory Space Control Upper


