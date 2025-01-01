; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Virtio Block Driver
; =============================================================================


; -----------------------------------------------------------------------------
virtio_blk_init:
	push rsi
	push rdx			; RDX should already point to a supported device for os_bus_read/write
	push rbx
	push rax

	; Verify this driver supports the Vendor
	mov eax, [rsi+4]		; Offset to Vendor/Device ID in the Bus Table
	mov rsi, virtio_blk_driverid
	mov bx, [rsi]			; Load the Vendor (0x1AF4)
	cmp ax, bx
	jne virtio_blk_init_error	; Bail out if it wasn't a match

	; Verify this driver support the Device
	shr eax, 16			; Move Device ID into AX
virtio_blk_init_next_dev:
	add rsi, 2
	mov bx, [rsi]			; Load the Device
	cmp bx, 0			; End of list?
	je virtio_blk_init_error	; If so, bail out
	cmp ax, bx			; Check against the list
	jne virtio_blk_init_next_dev	; No match? Try next entry

	; Grab the Base I/O Address of the device
	mov al, 4			; Read BAR4
	call os_bus_read_bar
	mov [os_virtioblk_base], rax	; Save it as the base
	mov rsi, rax			; RSI holds the base for MMIO

	; Set PCI Status/Command values
	mov dl, 0x01			; Read Status/Command
	call os_bus_read
	bts eax, 10			; Set Interrupt Disable
	bts eax, 2			; Enable Bus Master
	bts eax, 1			; Enable Memory Space
	call os_bus_write		; Write updated Status/Command

	; Gather required values from PCI Capabilities
	mov dl, 1
	call os_bus_read		; Read register 1 for Status/Command
	bt eax, 20			; Check bit 4 of the Status word (31:16)
	jnc virtio_blk_init_error	; If if doesn't exist then bail out
	mov dl, 13
	call os_bus_read		; Read register 13 for the Capabilities Pointer (7:0)
	and al, 0xFC			; Clear the bottom two bits as they are reserved

virtio_blk_init_cap_next:
	shr al, 2			; Quick divide by 4
	mov dl, al
	call os_bus_read
	cmp al, VIRTIO_PCI_CAP_VENDOR_CFG
	je virtio_blk_init_cap
	shr eax, 8
	jmp virtio_blk_init_cap_next_offset

virtio_blk_init_cap:
	rol eax, 8			; Move Virtio cfg_type to AL
	cmp al, VIRTIO_PCI_CAP_COMMON_CFG
	je virtio_blk_init_cap_common
	cmp al, VIRTIO_PCI_CAP_NOTIFY_CFG
	je virtio_blk_init_cap_notify
	ror eax, 16			; Move next entry offset to AL
	jmp virtio_blk_init_cap_next_offset

virtio_blk_init_cap_common:
	push rdx
	; TODO Check for BAR4 and offset of 0x0
	pop rdx
	jmp virtio_blk_init_cap_next_offset

virtio_blk_init_cap_notify:
	push rdx
	inc dl
	call os_bus_read
	pop rdx
	cmp al, 0x04			; Needs to be BAR4
	jne virtio_blk_init_error
	push rdx
	add dl, 2
	call os_bus_read
	mov [notify_offset], eax
	add dl, 2			; Skip Length
	call os_bus_read
	mov [notify_offset_multiplier], eax
	pop rdx
	jmp virtio_blk_init_cap_next_offset

virtio_blk_init_cap_next_offset:
	call os_bus_read
	shr eax, 8			; Shift pointer to AL
	cmp al, 0x00			; End of linked list?
	jne virtio_blk_init_cap_next	; If not, continue reading

virtio_blk_init_cap_end:

	; Device Initialization (section 3.1)

	; 3.1.1 - Step 1 -  Reset the device (section 2.4)
	mov al, 0x00			
	mov [rsi+VIRTIO_DEVICE_STATUS], al
virtio_blk_init_reset_wait:
	mov al, [rsi+VIRTIO_DEVICE_STATUS]
	cmp al, 0x00
	jne virtio_blk_init_reset_wait

	; 3.1.1 - Step 2 - Tell the device we see it
	mov al, VIRTIO_STATUS_ACKNOWLEDGE
	mov [rsi+VIRTIO_DEVICE_STATUS], al

	; 3.1.1 - Step 3 - Tell the device we support it
	mov al, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER
	mov [rsi+VIRTIO_DEVICE_STATUS], al

	; 3.1.1 - Step 4
	; Process the first 32-bits of Feature bits
	xor eax, eax
	mov [rsi+VIRTIO_DEVICE_FEATURE_SELECT], eax
	mov eax, [rsi+VIRTIO_DEVICE_FEATURE]
;	btc eax, VIRTIO_BLK_F_MQ	; Disable Multiqueue support for this driver
;	btc eax, VIRTIO_F_INDIRECT_DESC
	mov eax, 0x44			; Only support BLK_SIZE (6) & SEG_MAX (2)
	push rax
	xor eax, eax
	mov [rsi+VIRTIO_DRIVER_FEATURE_SELECT], eax
	pop rax
	mov [rsi+VIRTIO_DRIVER_FEATURE], eax
	; Process the next 32-bits of Feature bits
	mov eax, 1
	mov [rsi+VIRTIO_DEVICE_FEATURE_SELECT], eax
	mov eax, [rsi+VIRTIO_DEVICE_FEATURE]
	and eax, 1
	push rax
	mov eax, 1
	mov [rsi+VIRTIO_DRIVER_FEATURE_SELECT], eax
	pop rax
	mov [rsi+VIRTIO_DRIVER_FEATURE], eax

	; 3.1.1 - Step 5
	mov al, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_FEATURES_OK
	mov [rsi+VIRTIO_DEVICE_STATUS], al

	; 3.1.1 - Step 6 - Re-read device status to make sure FEATURES_OK is still set
	mov al, [rsi+VIRTIO_DEVICE_STATUS]
	bt ax, 3			; VIRTIO_STATUS_FEATURES_OK
	jnc virtio_blk_init_error

	; 3.1.1 - Step 7
	; Set up the device and the queues
	; discovery of virtqueues for the device
	; optional per-bus setup
	; reading and possibly writing the device’s virtio configuration space
	; population of virtqueues

	; Set up Queue 0
	xor eax, eax
	mov [rsi+VIRTIO_QUEUE_SELECT], ax
	mov ax, [rsi+VIRTIO_QUEUE_SIZE]	; Return the size of the queue
	mov ecx, eax			; Store queue size in ECX
	mov eax, os_storage_mem
	mov [rsi+VIRTIO_QUEUE_DESC], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DESC+8], eax
	rol rax, 32
	add rax, 4096
	mov [rsi+VIRTIO_QUEUE_DRIVER], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DRIVER+8], eax
	rol rax, 32
	add rax, 4096
	mov [rsi+VIRTIO_QUEUE_DEVICE], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DEVICE+8], eax
	rol rax, 32
	mov ax, 1
	mov [rsi+VIRTIO_QUEUE_ENABLE], ax

	; Populate the Next entries in the description ring
	; FIXME - Don't expect exactly 256 entries
	mov eax, 1
	mov rdi, os_storage_mem
	add rdi, 14
virtio_blk_init_pop:
	mov [rdi], al
	add rdi, 16
	add al, 1
	cmp al, 0
	jne virtio_blk_init_pop

	; 3.1.1 - Step 8 - At this point the device is “live”
	mov al, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_DRIVER_OK | VIRTIO_STATUS_FEATURES_OK
	mov [rsi+VIRTIO_DEVICE_STATUS], al

virtio_blk_init_done:
	bts word [os_StorageVar], 3	; Set the bit flag that Virtio Block has been initialized
	mov rdi, os_storage_io		; Write over the storage function addresses
	mov rax, virtio_blk_io
	stosq
	mov rax, virtio_blk_id
	stosq
	pop rax
	pop rbx
	pop rdx
	pop rsi
	add rsi, 15
	mov byte [rsi], 1		; Mark driver as installed in Bus Table
	sub rsi, 15
	ret

virtio_blk_init_error:
	pop rax
	pop rbx
	pop rdx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; virtio_blk_io -- Perform an I/O operation on a VIRTIO Block device
; IN:	RAX = starting sector #
;	RBX = I/O Opcode
;	RCX = number of sectors
;	RDX = drive #
;	RDI = memory location used for reading/writing data from/to device
; OUT:	Nothing
;	All other registers preserved
virtio_blk_io:
	push r9
	push rdi
	push rdx
	push rcx
	push rbx
	push rax

	push rax			; Save the starting sector
	mov r9, rdi			; Save the memory address

	mov rdi, os_storage_mem		; This driver always starts at beginning of the Descriptor Table
					; FIXME: Add desc_index offset

	; Add header to Descriptor Entry 0
	mov rax, header			; Address of the header
	stosq				; 64-bit address
	mov eax, 16
	stosd				; 32-bit length
	mov ax, VIRTQ_DESC_F_NEXT
	stosw				; 16-bit Flags
	add rdi, 2			; Skip Next as it is pre-populated

	; Add data to Descriptor Entry 1
	mov rax, r9			; Address to store the data
	stosq
	shl rcx, 12			; Covert count to 4096B sectors
	mov eax, ecx			; Number of bytes
	stosd
	mov ax, VIRTQ_DESC_F_NEXT | VIRTQ_DESC_F_WRITE
	stosw				; 16-bit Flags
	add rdi, 2			; Skip Next as it is pre-populated

	; Add footer to Descriptor Entry 3
	mov rax, footer			; Address of the footer
	stosq				; 64-bit address
	mov eax, 1
	stosd				; 32-bit length
	mov eax, VIRTQ_DESC_F_WRITE
	stosw				; 16-bit Flags
	add rdi, 2			; Skip Next as it is pre-populated

	; Build the header
	mov rdi, header
	; BareMetal I/O opcode for Read is 2, Write is 1
	; Virtio-blk I/O opcode for Read is 0, Write is 1
	; FIXME: Currently we just clear bit 1.
	btc bx, 1
	mov eax, ebx
	stosd				; type
	xor eax, eax
	stosd				; reserved
	pop rax				; Restore the starting sector
	shl rax, 3			; Multiply by 8 as we use 4096-byte sectors internally
	stosq				; starting sector

	; Build the footer
	mov rdi, footer
	xor eax, eax
	stosb

	; Add entry to Avail
	mov rdi, os_storage_mem+0x1000	; Offset to start of Availability Ring
	mov ax, 1			; 1 for no interrupts
	stosw				; 16-bit flags
	mov ax, [availindex]
	stosw				; 16-bit index
	mov ax, 0
	stosw				; 16-bit ring

	; Notify the queue
	mov rdi, [os_virtioblk_base]
	add rdi, [notify_offset]	; This driver only uses Queue 0 so no multiplier needed
	xor eax, eax
	stosw

	; Inspect the used ring
	mov rdi, os_storage_mem+0x2002	; Offset to start of Used Ring
	mov bx, [availindex]
virtio_blk_io_wait:
	mov ax, [rdi]			; Load the index
	cmp ax, bx
	jne virtio_blk_io_wait

	add word [descindex], 3		; 3 entries were required
	add word [availindex], 1

	pop rax
	pop rbx
	pop rcx
	pop rdx
	pop rdi
	pop r9
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; virtio_blk_id -- 
; IN:	EAX = CDW0
;	EBX = CDW1
;	ECX = CDW10
;	EDX = CDW11
;	RDI = CDW6-7
; OUT:	Nothing
;	All other registers preserved
virtio_blk_id:
	ret
; -----------------------------------------------------------------------------

; Variables
notify_offset: dq 0
notify_offset_multiplier: dq 0
descindex: dw 0
availindex: dw 1

; Driver
virtio_blk_driverid:
dw 0x1AF4				; Vendor ID
dw 0x1001				; Device ID - legacy
dw 0x1042				; Device ID - v1.0
dw 0x0000				; End of list

align 16
footer:
db 0x00

align 16
header:
dd 0x00					; 32-bit type
dd 0x00					; 32-bit reserved
dq 0					; 64-bit sector

; VIRTIO BLK Registers
VIRTIO_BLK_CAPACITY				equ 0x14 ; 64-bit Capacity (in 512-byte sectors)
VIRTIO_BLK_SIZE_MAX				equ 0x1C ; 32-bit Maximum Segment Size
VIRTIO_BLK_SEG_MAX				equ 0x20 ; 32-bit Maximum Segment Count
VIRTIO_BLK_CYLINDERS				equ 0x24 ; 16-bit Cylinder Count
VIRTIO_BLK_HEADS				equ 0x26 ; 8-bit Head Count
VIRTIO_BLK_SECTORS				equ 0x27 ; 8-bit Sector Count
VIRTIO_BLK_BLK_SIZE				equ 0x28 ; 32-bit Block Length
VIRTIO_BLK_PHYSICAL_BLOCK_EXP			equ 0x2C ; 8-bit # OF LOGICAL BLOCKS PER PHYSICAL BLOCK (LOG2)
VIRTIO_BLK_ALIGNMENT_OFFSET			equ 0x2D ; 8-bit OFFSET OF FIRST ALIGNED LOGICAL BLOCK
VIRTIO_BLK_MIN_IO_SIZE				equ 0x2E ; 16-bit SUGGESTED MINIMUM I/O SIZE IN BLOCKS
VIRTIO_BLK_OPT_IO_SIZE				equ 0x30 ; 32-bit OPTIMAL (SUGGESTED MAXIMUM) I/O SIZE IN BLOCKS
VIRTIO_BLK_WRITEBACK				equ 0x34 ; 8-bit
VIRTIO_BLK_NUM_QUEUES				equ 0x36 ; 16-bit
VIRTIO_BLK_MAX_DISCARD_SECTORS			equ 0x38 ; 32-bit 
VIRTIO_BLK_MAX_DISCARD_SEG			equ 0x3C ; 32-bit 
VIRTIO_BLK_DISCARD_SECTOR_ALIGNMENT		equ 0x40 ; 32-bit 
VIRTIO_BLK_MAX_WRITE_ZEROES_SECTORS		equ 0x44 ; 32-bit 
VIRTIO_BLK_MAX_WRITE_ZEROES_SEG			equ 0x48 ; 32-bit 
VIRTIO_BLK_WRITE_ZEROES_MAY_UNMAP		equ 0x4C ; 8-bit
VIRTIO_BLK_MAX_SECURE_ERASE_SECTORS		equ 0x50 ; 32-bit 
VIRTIO_BLK_MAX_SECURE_ERASE_SEG			equ 0x54 ; 32-bit 
VIRTIO_BLK_SECURE_ERASE_SECTOR_ALIGNMENT	equ 0x58 ; 32-bit 

; VIRTIO_DEVICEFEATURES bits
VIRTIO_BLK_F_BARRIER			equ 0 ; Legacy - Device supports request barriers
VIRTIO_BLK_F_SIZE_MAX			equ 1 ; Maximum size of any single segment is in size_max
VIRTIO_BLK_F_SEG_MAX			equ 2 ; Maximum number of segments in a request is in seg_max
VIRTIO_BLK_F_GEOMETRY			equ 4 ; Disk-style geometry specified in geometry
VIRTIO_BLK_F_RO				equ 5 ; Device is read-only
VIRTIO_BLK_F_BLK_SIZE			equ 6 ; Block size of disk is in blk_size
VIRTIO_BLK_F_SCSI			equ 7 ; Legacy - Device supports scsi packet commands
VIRTIO_BLK_F_FLUSH			equ 9 ; Cache flush command support
VIRTIO_BLK_F_TOPOLOGY			equ 10 ; Device exports information on optimal I/O alignment
VIRTIO_BLK_F_CONFIG_WCE			equ 11 ; Device can toggle its cache between writeback and writethrough modes
VIRTIO_BLK_F_MQ				equ 12 ; Device supports multiqueue
VIRTIO_BLK_F_DISCARD			equ 13 ; Device can support discard command
VIRTIO_BLK_F_WRITE_ZEROES		equ 14 ; Device can support write zeroes command
VIRTIO_BLK_F_LIFETIME			equ 15 ; Device supports providing storage lifetime information
VIRTIO_BLK_F_SECURE_ERASE		equ 16 ; Device supports secure erase command

; VIRTIO Block Types
VIRTIO_BLK_T_IN				equ 0 ; Read from device
VIRTIO_BLK_T_OUT			equ 1 ; Write to device
VIRTIO_BLK_T_FLUSH			equ 4 ; Flush
VIRTIO_BLK_T_GET_ID			equ 8 ; Get device ID string
VIRTIO_BLK_T_GET_LIFETIME		equ 10 ; Get device lifetime
VIRTIO_BLK_T_DISCARD			equ 11 ; Discard
VIRTIO_BLK_T_WRITE_ZEROES		equ 13 ; Write zeros
VIRTIO_BLK_T_SECURE_ERASE		equ 14 ; Secure erase


; =============================================================================
; EOF