; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; Virtio Block Driver
; =============================================================================


; -----------------------------------------------------------------------------
virtio_blk_init:
	push rdx
	push rax

	; Todo
	; Make sure the PCI Vendor and Device IDs match what this drive supports
	; Vendor 0x1af4, Device 0x1001
	; Get the proper IO address instead of using the known QEMU port below
	mov edx, 0xc000
	mov qword [os_virtioblk_base], rdx

	; Device Initialization (section 3.1)

	; 3.1.1 - Step 1
	mov edx, [os_virtioblk_base]
	add dx, VIRTIO_DEVICESTATUS
	mov al, 0x00
	out dx, al			; Reset the device (section 2.4)

	; 3.1.1 - Step 2
	mov al, VIRTIO_STATUS_ACKNOWLEDGE
	out dx, al			; Tell the device we see it

	; 3.1.1 - Step 3
	mov al, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER
	out dx, al			; Tell the device we support it

	; 3.1.1 - Step 4
	mov edx, [os_virtioblk_base]
	in eax, dx			; Read DEVICEFEATURES
	btc eax, VIRTIO_BLK_F_MQ	; Disable Multiqueue support for this driver
	add dx, VIRTIO_HOSTFEATURES
	out dx, eax			; Write supported features to HOSTFEATURES

	; 3.1.1 - Step 5
	mov edx, [os_virtioblk_base]
	add dx, VIRTIO_DEVICESTATUS
	mov al, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_FEATURES_OK
	out dx, al

	; 3.1.1 - Step 6
	in al, dx			; Re-read device status to make sure FEATURES_OK is still set
	bt ax, 3 ;VIRTIO_STATUS_FEATURES_OK
	jnc virtio_blk_error

	; 3.1.1 - Step 7
	; Set up the device and the queues
	; discovery of virtqueues for the device
	; optional per-bus setup
	; reading and possibly writing the device’s virtio configuration space
	; population of virtqueues

	; FIXME (or not?) - This only sets up queue 0
	xor ebx, ebx			; Counter for number of queues with sizes > 0
	mov edx, [os_virtioblk_base]
	add dx, VIRTIO_QUEUESELECT
	mov ax, bx
	out dx, ax			; Select the Queue
	mov edx, [os_virtioblk_base]
	add dx, VIRTIO_QUEUESIZE
	xor eax, eax
	in ax, dx			; Return the size of the queue

	; Set up the required buffers in memory
	mov ecx, eax			; Store queue size in ECX

	mov edx, [os_virtioblk_base]
	add dx, VIRTIO_QUEUEADDRESS
	mov eax, os_storage_mem
	shr eax, 12
	out dx, eax			; Point Queue 0 to os_rx_desc

	; 3.1.1 - Step 8
	mov edx, [os_virtioblk_base]
	add dx, VIRTIO_DEVICESTATUS
	mov al, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_DRIVER_OK | VIRTIO_STATUS_FEATURES_OK
	out dx, al			; At this point the device is “live”

	; Reset the device
;	call net_virtio_reset

	; Try to read a sector
	push rdi
	mov rdi, 0x140000		; TX Queue
	
	; Add header to Buffers
	mov rax, testheader		; header for virtio
	stosq				; 64-bit address
	mov eax, 16
	stosd				; 32-bit length
	mov ax, VIRTQ_DESC_F_NEXT
	stosw				; 16-bit Flags
	mov ax, 1
	stosw				; 16-bit Next

	; Add data to Buffers
	mov rax, 0x400000		; Address to store the data
	stosq
	mov eax, 1024			; Number of bytes
	stosd
	mov ax, VIRTQ_DESC_F_NEXT | VIRTQ_DESC_F_WRITE
	stosw				; 16-bit Flags
	mov ax, 2
	stosw				; 16-bit Next

	mov rax, testendheader
	stosq				; 64-bit address
	mov eax, 1
	stosd				; 32-bit length
	mov eax, VIRTQ_DESC_F_WRITE
	stosw				; 16-bit Flags
	mov eax, 3
	stosw				; 16-bit Next

	; Add entry to Avail
	mov rdi, 0x141000		; Offset to start of Availability ring
	mov ax, 1
	stosw				; 16-bit flags
	mov ax, 1
	stosw				; 16-bit index
	mov ax, 0
	stosw				; 16-bit ring
	mov ax, 2
	stosw				; 16-bit eventindex
	
	pop rdi
	
	mov edx, [os_virtioblk_base]
	add dx, VIRTIO_QUEUESELECT
	mov ax, 0
	out dx, ax			; Select the Queue
	mov edx, [os_virtioblk_base]
	add dx, VIRTIO_QUEUENOTIFY
	xor eax, eax
	out dx, ax

virtio_blk_error:
	pop rax
	pop rdx
	ret
; -----------------------------------------------------------------------------


; Driver
virtio_blk_driverid:
dw 0x1AF4		; Vendor ID
dw 0x1000		; Device ID

align 16
testendheader:
db 0x00

align 16
testheader:
dd 0x00					; 32-bit type
dd 0x00					; 32-bit reserved
dq 0					; 64-bit sector
db 0					; 8-bit data
db 0					; 8-bit status

testdata:


; VIRTIO_DEVICEFEATURES bits
VIRTIO_BLK_F_BARRIER		equ 0 ; Legacy - Device supports request barriers
VIRTIO_BLK_F_SIZE_MAX		equ 1 ; Maximum size of any single segment is in size_max
VIRTIO_BLK_F_SEG_MAX		equ 2 ; Maximum number of segments in a request is in seg_max
VIRTIO_BLK_F_GEOMETRY		equ 4 ; Disk-style geometry specified in geometry
VIRTIO_BLK_F_RO			equ 5 ; Device is read-only
VIRTIO_BLK_F_BLK_SIZE		equ 6 ; Block size of disk is in blk_size
VIRTIO_BLK_F_SCSI		equ 7 ; Legacy - Device supports scsi packet commands
VIRTIO_BLK_F_FLUSH		equ 9 ; Cache flush command support
VIRTIO_BLK_F_TOPOLOGY		equ 10 ; Device exports information on optimal I/O alignment
VIRTIO_BLK_F_CONFIG_WCE		equ 11 ; Device can toggle its cache between writeback and writethrough modes
VIRTIO_BLK_F_MQ			equ 12 ; Device supports multiqueue
VIRTIO_BLK_F_DISCARD		equ 13 ; Device can support discard command
VIRTIO_BLK_F_WRITE_ZEROES	equ 14 ; Device can support write zeroes command
VIRTIO_BLK_F_LIFETIME		equ 15 ; Device supports providing storage lifetime information
VIRTIO_BLK_F_SECURE_ERASE	equ 16 ; Device supports secure erase command

; VIRTIO Block Types
VIRTIO_BLK_T_IN			equ 0 ; Read from device
VIRTIO_BLK_T_OUT		equ 1 ; Write to device
VIRTIO_BLK_T_FLUSH		equ 4 ; Flush
VIRTIO_BLK_T_GET_ID		equ 8 ; Get device ID string
VIRTIO_BLK_T_GET_LIFETIME	equ 10 ; Get device lifetime
VIRTIO_BLK_T_DISCARD		equ 11 ; Discard
VIRTIO_BLK_T_WRITE_ZEROES	equ 13 ; Write zeros
VIRTIO_BLK_T_SECURE_ERASE	equ 14 ; Secure erase


; =============================================================================
; EOF