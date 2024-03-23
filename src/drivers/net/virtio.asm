; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; Virtio NIC Driver
; =============================================================================


; -----------------------------------------------------------------------------
; Initialize a Virtio NIC
;  IN:	RDX = Packed Bus address (as per syscalls/bus.asm)
net_virtio_init:
	push rdx			; I/O Port
	push rcx			; Buffer size
	push rbx			; # of Queues
	push rax			; I/O Value

	; Grab the Base I/O Address of the device
	mov dl, 0x04			; BAR0
	call os_bus_read
	; Todo: Make sure bit 0 is 1
	and eax, 0xFFFFFFFC		; Clear the low two bits
	mov dword [os_NetIOBaseMem], eax

	; Grab the IRQ of the device
	mov dl, 0x0F			; Get device's IRQ number from Bus Register 15 (IRQ is bits 7-0)
	call os_bus_read
	mov [os_NetIRQ], al		; AL holds the IRQ

	; Grab the MAC address
	mov edx, [os_NetIOBaseMem]
	add edx, VIRTIO_NET_MAC1
	in al, dx
	mov [os_NetMAC], al
	inc dx
	in al, dx
	mov [os_NetMAC+1], al
	inc dx
	in al, dx
	mov [os_NetMAC+2], al
	inc dx
	in al, dx
	mov [os_NetMAC+3], al
	inc dx
	in al, dx
	mov [os_NetMAC+4], al
	inc dx
	in al, dx
	mov [os_NetMAC+5], al

	; Device Initialization (section 3.1)

	; 3.1.1 - Step 1
	mov edx, [os_NetIOBaseMem]
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
	mov edx, [os_NetIOBaseMem]
	in eax, dx			; Read DEVICEFEATURES
	btc eax, VIRTIO_NET_F_MQ	; Disable Multiqueue support for this driver
	add dx, VIRTIO_HOSTFEATURES
	out dx, eax			; Write supported features to HOSTFEATURES

	; 3.1.1 - Step 5
	mov edx, [os_NetIOBaseMem]
	add dx, VIRTIO_DEVICESTATUS
	mov al, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_FEATURES_OK
	out dx, al

	; 3.1.1 - Step 6
	in al, dx			; Re-read device status to make sure FEATURES_OK is still set
	bt ax, 3 ;VIRTIO_STATUS_FEATURES_OK
	jnc net_virtio_error

	; 3.1.1 - Step 7
	; Set up the device and the queues
	; discovery of virtqueues for the device
	; optional per-bus setup
	; reading and possibly writing the device’s virtio configuration space
	; population of virtqueues

	xor ebx, ebx			; Counter for number of queues with sizes > 0
net_virtio_check_queues:
	; Check the first queue and make sure it has a size > 0
	mov edx, [os_NetIOBaseMem]
	add dx, VIRTIO_QUEUESELECT
	mov ax, bx
	out dx, ax			; Select the Queue
	mov edx, [os_NetIOBaseMem]
	add dx, VIRTIO_QUEUESIZE
	xor eax, eax
	in ax, dx			; Return the size of the queue
	inc ebx
	cmp ax, 0			; If the Queue Size in 0 we have reached the end of the queues
	je net_virtio_end_queues

net_virtio_init_queues:
	; Set up the required buffers in memory
	mov ecx, eax			; Store queue size in ECX

	; Figure out home much memory we need for the queue
	; A full queue is as follows:
	; Buffers -> QueueSize * 8
	; Available -> 8
	; Align to next 4KB
	; Used -> 4 + (Ring -> QueueSize * 8) + 2

;	shl eax, 4			; quick multiply by 16 as each buffer entry is 16 bytes
					; 256 entries is 2048 bytes

	; TODO This uses hardcoded values which is bad
	mov edx, [os_NetIOBaseMem]
	add dx, VIRTIO_QUEUEADDRESS
	mov eax, os_net_mem
	sub ebx, 1
	shl rbx, 14			; Quick multiply by 16384
	add rax, rbx
	shr rbx, 14			; Quick multiply by 16384
	shr eax, 12
	add ebx, 1
	out dx, eax			; Point Queue 0 to os_rx_desc
	jmp net_virtio_check_queues	; Check the next queue

net_virtio_end_queues:
	cmp bx, 0
	je net_virtio_error

	; 3.1.1 - Step 8
	mov edx, [os_NetIOBaseMem]
	add dx, VIRTIO_DEVICESTATUS
	mov al, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_DRIVER_OK | VIRTIO_STATUS_FEATURES_OK
	out dx, al			; At this point the device is “live”

	; Reset the device
;	call net_virtio_reset

	; Try to send an Ethernet packet
	push rdi
	mov rdi, 0x1a4000		; TX Queue

	; Add header and packet to Buffers
	mov rax, testpacket		; packet header for virtio
	stosq				; 64-bit address
	mov eax, 12
	stosd				; 32-bit length
	mov ax, 1
	stosw				; 16-bit Flags
	stosw				; 16-bit Next

	mov rax, testpacketdata		; actual packet
	stosq				; 64-bit address
	mov rax, 500
	stosd				; 32-bit length
	mov ax, 0
	stosw				; 16-bit Flags
	stosw				; 16-bit Next

	; Add entry to Avail
	mov rdi, 0x1a5000
	mov ax, 1
	stosw				; 16-bit flags
	mov ax, 1
	stosw				; 16-bit index
	mov ax, 1
	stosw				; 16-bit ring
	mov ax, 2
	stosw				; 16-bit eventindex

	pop rdi

	mov edx, [os_NetIOBaseMem]
	add dx, VIRTIO_QUEUESELECT
	mov ax, VIRTIO_NET_QUEUE_TX
	out dx, ax			; Select the Queue
	mov edx, [os_NetIOBaseMem]
	add dx, VIRTIO_QUEUENOTIFY
	xor eax, eax
	out dx, ax

net_virtio_error:
net_virtion_init_end:
	pop rax
	pop rbx
	pop rcx
	pop rdx
	ret
; -----------------------------------------------------------------------------

align 16
testpacket:
db 0x02					; 8-bit flags (1 - needs checksum, 2 - data valid)
db 0x00					; 8-bit gso_type
dw 0					; 16-bit hdr_len
dw 0					; 16-bit gso_size
dw 0					; 16-bit csum_start
dw 0					; 16-bit csum_offset
dw 0					; 16-bit num_buffers
testpacketdata:
db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF		; wut?
db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF		; wut?
db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
db 0x10, 0x11, 0x12, 0x13, 0x14, 0x15
db 0xAB, 0xBA
db 'this is a test packet'

; -----------------------------------------------------------------------------
; net_virtio_reset - Reset a Virtio NIC
;  IN:	Nothing
; OUT:	Nothing, all registers preserved
net_virtio_reset:


; Acknowledge

; Driver

; Queue

	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_virtio_transmit - Transmit a packet via a Virtio NIC
;  IN:	RSI = Location of packet
;	RCX = Length of packet
; OUT:	Nothing
net_virtio_transmit:

	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_virtio_poll - Polls the Virtio NIC for a received packet
;  IN:	RDI = Location to store packet
; OUT:	RCX = Length of packet
net_virtio_poll:

	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_virtio_ack_int - Acknowledge an internal interrupt of the Virtio NIC
;  IN:	Nothing
; OUT:	RAX = Ethernet status
;	Uses RDI
net_virtio_ack_int:

	ret
; -----------------------------------------------------------------------------


; VIRTIO Common Registers
VIRTIO_DEVICEFEATURES		equ 0x00 ; 32-bit Read-only
VIRTIO_HOSTFEATURES		equ 0x04 ; 32-bit
VIRTIO_QUEUEADDRESS		equ 0x08 ; 32-bit
VIRTIO_QUEUESIZE		equ 0x0C ; 16-bit Read-only
VIRTIO_QUEUESELECT		equ 0x0E ; 16-bit
VIRTIO_QUEUENOTIFY		equ 0x10 ; 16-bit
VIRTIO_DEVICESTATUS		equ 0x12 ; 8-bit
VIRTIO_ISRSTATUS		equ 0x13 ; 8-bit Read-only

; VIRTIO NET Registers
VIRTIO_NET_MAC1			equ 0x14 ; 8-bit
VIRTIO_NET_MAC2			equ 0x15 ; 8-bit
VIRTIO_NET_MAC3			equ 0x16 ; 8-bit
VIRTIO_NET_MAC4			equ 0x17 ; 8-bit
VIRTIO_NET_MAC5			equ 0x18 ; 8-bit
VIRTIO_NET_MAC6			equ 0x19 ; 8-bit
VIRTIO_NET_STATUS		equ 0x1A ; 16-bit
VIRTIO_NET_MAX_VIRTQ_PAIRS	equ 0x1C ; 16-bit
VIRTIO_NET_MTU			equ 0x1E ; 16-bit
VIRTIO_NET_SPEED		equ 0x20 ; 32-bit in units of 1 MBit per second, 0 to 0x7fffffff, or 0xffffffff for unknown
VIRTIO_NET_DUPLEX		equ 0x24 ; 8-bit 0x01 for full duplex, 0x00 for half duplex
VIRTIO_NET_RSS_MAX_KEY_SIZE	equ 0x25 ; 8-bit
VIRTIO_NET_RSS_MAX_INT_TAB_LEN	equ 0x26 ; 16-bit
VIRTIO_NET_SUPPORTED_HASH_TYPES	equ 0x28 ; 32-bit

; VIRTIO_DEVICEFEATURES bits
VIRTIO_NET_F_CSUM		equ 0 ; Device handles packets with partial checksum
VIRTIO_NET_F_GUEST_CSUM		equ 1 ; Driver handles packets with partial checksum
VIRTIO_NET_F_CTRL_GUEST_OFFLOADS	equ 2 ; Control channel offloads reconfiguration support
VIRTIO_NET_F_MTU		equ 3 ; Device maximum MTU reporting is supported
VIRTIO_NET_F_MAC		equ 5 ; Device has given MAC address
VIRTIO_NET_F_GSO		equ 6 ; LEGACY Device handles packets with any GSO type
VIRTIO_NET_F_GUEST_TSO4		equ 7 ; Driver can receive TSOv4
VIRTIO_NET_F_GUEST_TSO6		equ 8 ; Driver can receive TSOv6
VIRTIO_NET_F_GUEST_ECN		equ 9 ; Driver can receive TSO with ECN
VIRTIO_NET_F_GUEST_UFO		equ 10 ; Driver can receive UFO
VIRTIO_NET_F_HOST_TSO4		equ 11 ; Device can receive TSOv4
VIRTIO_NET_F_HOST_TSO6		equ 12 ; Device can receive TSOv6
VIRTIO_NET_F_HOST_ECN		equ 13 ; Device can receive TSO with ECN
VIRTIO_NET_F_HOST_UFO		equ 14 ; Device can receive UFO
VIRTIO_NET_F_MRG_RXBUF		equ 15 ; Driver can merge receive buffers
VIRTIO_NET_F_STATUS		equ 16 ; Configuration status field is available
VIRTIO_NET_F_CTRL_VQ		equ 17 ; Control channel is available
VIRTIO_NET_F_CTRL_RX		equ 18 ; Control channel RX mode support
VIRTIO_NET_F_CTRL_VLAN		equ 19 ; Control channel VLAN filtering
VIRTIO_NET_F_CTRL_RX_EXTRA	equ 20 ; ???
VIRTIO_NET_F_GUEST_ANNOUNCE	equ 21 ; Driver can send gratuitous packets
VIRTIO_NET_F_MQ			equ 22 ; Device supports multiqueue with automatic receive steering
VIRTIO_NET_F_CTRL_MAC_ADDR	equ 23 ; Set MAC address through control channel
VIRTIO_NET_F_GUEST_RSC4		equ 41 ; LEGACY Device coalesces TCPIP v4 packets
VIRTIO_NET_F_GUEST_RSC6		equ 42 ; LEGACY Device coalesces TCPIP v6 packets
VIRTIO_NET_F_HOST_USO		equ 56 ; Device can receive USO packets
VIRTIO_NET_F_HASH_REPORT	equ 57 ; Device can report per-packet hash value and a type of calculated hash.
VIRTIO_NET_F_GUEST_HDRLEN	equ 59 ; Driver can provide the exact hdr_len value. Device benefits from knowing the exact header length.
VIRTIO_NET_F_RSS		equ 60 ; Device supports RSS (receive-side scaling) with Toeplitz hash calculation and configurable hash parameters for receive steering.
VIRTIO_NET_F_RSC_EXT		equ 61 ; Device can process duplicated ACKs and report number of coalesced segments and duplicated ACKs.
VIRTIO_NET_F_STANDBY		equ 62 ; Device may act as a standby for a primary device with the same MAC address.
VIRTIO_NET_F_SPEED_DUPLEX	equ 63 ; Device reports speed and duplex

; VIRTIO_STATUS
VIRTIO_STATUS_FAILED		equ 0x80 ; Indicates that something went wrong in the guest, and it has given up on the device
VIRTIO_STATUS_DEVICE_NEEDS_RESET	equ 0x40 ; Indicates that the device has experienced an error from which it can’t recover
VIRTIO_STATUS_FEATURES_OK	equ 0x08 ; Indicates that the driver has acknowledged all the features it understands, and feature negotiation is complete
VIRTIO_STATUS_DRIVER_OK		equ 0x04 ; Indicates that the driver is set up and ready to drive the device
VIRTIO_STATUS_DRIVER		equ 0x02 ; Indicates that the guest OS knows how to drive the device
VIRTIO_STATUS_ACKNOWLEDGE	equ 0x01 ; Indicates that the guest OS has found the device and recognized it as a valid virtio device.

; VIRTQUEUE Flags
VIRTQ_DESC_F_NEXT		equ 1
VIRTQ_DESC_F_WRITE		equ 2
VIRTQ_DESC_F_INDIRECT		equ 4

; VIRTQUEUES
VIRTIO_NET_QUEUE_RX		equ 0	; The first of the Receive Queues
VIRTIO_NET_QUEUE_TX		equ 1	; The first of the Transmit Queues


; =============================================================================
; EOF
