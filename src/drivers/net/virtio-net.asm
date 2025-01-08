; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Virtio NIC Driver
; =============================================================================


; -----------------------------------------------------------------------------
; Initialize a Virtio NIC
;  IN:	RDX = Packed Bus address (as per syscalls/bus.asm)
net_virtio_init:
	push rsi
	push rdx
	push rcx
	push rbx
	push rax

	; Get the Base Memory Address of the device
	mov al, 4			; Read BAR4
	call os_bus_read_bar
	mov [os_NetIOBaseMem], rax	; Save it as the base
	mov [os_NetIOLength], rcx	; Save the length

	; Set PCI Status/Command values
	mov dl, 0x01			; Read Status/Command
	call os_bus_read
	bts eax, 10			; Set Interrupt Disable
	bts eax, 1			; Enable Memory Space
	call os_bus_write

	; Get required values from PCI Capabilities
	mov dl, 1
	call os_bus_read		; Read register 1 for Status/Command
	bt eax, 20			; Check bit 4 of the Status word (31:16)
	jnc virtio_net_init_error	; If if doesn't exist then bail out
	mov dl, 13
	call os_bus_read		; Read register 13 for the Capabilities Pointer (7:0)
	and al, 0xFC			; Clear the bottom two bits as they are reserved

virtio_net_init_cap_next:
	shr al, 2			; Quick divide by 4
	mov dl, al
	call os_bus_read
	cmp al, VIRTIO_PCI_CAP_VENDOR_CFG
	je virtio_net_init_cap
	cmp al, 0x11
	je virtio_net_init_msix
	shr eax, 8
	jmp virtio_net_init_cap_next_offset

virtio_net_init_msix:
	push rdx

	; Enable MSI-X, Mask it, Get Table Size
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
	mov rdi, rax
	pop rdx

	; Configure MSI-X Table
	add cx, 1			; Table Size is 0-indexed
virtio_net_init_msix_entry:
	mov rax, [os_LocalAPICAddress]	; 0xFEE for bits 31:20, Dest (19:12), RH (3), DM (2)
	stosd				; Store Message Address Low
	shr rax, 32			; Rotate the high bits to EAX
	stosd				; Store Message Address High
	mov eax, 0x000040AB		; Trigger Mode (15), Level (14), Delivery Mode (10:8), Vector (7:0)
	stosd				; Store Message Data
	xor eax, eax			; Bits 31:1 are reserved, Masked (0) - 1 for masked
	stosd				; Store Vector Control
	dec cx
	cmp cx, 0
	jne virtio_net_init_msix_entry
	pop rdx

	; Unmask MSI-X
	call os_bus_read
	btc eax, 30			; Clear Function Mask
	call os_bus_write

	jmp virtio_net_init_cap_next_offset

virtio_net_init_cap:
	rol eax, 8			; Move Virtio cfg_type to AL
	cmp al, VIRTIO_PCI_CAP_COMMON_CFG
	je virtio_net_init_cap_common
	cmp al, VIRTIO_PCI_CAP_NOTIFY_CFG
	je virtio_net_init_cap_notify
	cmp al, VIRTIO_PCI_CAP_ISR_CFG
	je virtio_net_init_cap_isr
	cmp al, VIRTIO_PCI_CAP_DEVICE_CFG
	je virtio_net_init_cap_device
	ror eax, 16			; Move next entry offset to AL
	jmp virtio_net_init_cap_next_offset

virtio_net_init_cap_common:
	push rdx
	; TODO Check for BAR4 and offset of 0x0
	pop rdx
	jmp virtio_net_init_cap_next_offset

virtio_net_init_cap_notify:
	push rdx
	inc dl
	call os_bus_read
	pop rdx
	cmp al, 0x04			; Needs to be BAR4
	jne virtio_net_init_error
	push rdx
	add dl, 2
	call os_bus_read
	mov [virtio_net_notify_offset], eax
	add dl, 2			; Skip Length
	call os_bus_read
	mov [virtio_net_notify_offset_multiplier], eax
	pop rdx
	jmp virtio_net_init_cap_next_offset

virtio_net_init_cap_device:
	push rdx
	add dl, 2
	call os_bus_read
	mov [virtio_net_device_offset], eax
	pop rdx
	jmp virtio_net_init_cap_next_offset

virtio_net_init_cap_isr:
	push rdx
	add dl, 2
	call os_bus_read
	mov [virtio_net_isr_offset], eax
	pop rdx
	jmp virtio_net_init_cap_next_offset

virtio_net_init_cap_next_offset:
	call os_bus_read
	shr eax, 8			; Shift pointer to AL
	cmp al, 0x00			; End of linked list?
	jne virtio_net_init_cap_next	; If not, continue reading

virtio_net_init_cap_end:

	; Get the MAC address
	mov rsi, [os_NetIOBaseMem]
	add rsi, [virtio_net_device_offset]
	lodsb
	mov [os_NetMAC], al
	lodsb
	mov [os_NetMAC+1], al
	lodsb
	mov [os_NetMAC+2], al
	lodsb
	mov [os_NetMAC+3], al
	lodsb
	mov [os_NetMAC+4], al
	lodsb
	mov [os_NetMAC+5], al

	call net_virtio_reset

virtio_net_init_error:
	pop rax
	pop rbx
	pop rcx
	pop rdx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_virtio_reset - Reset a Virtio NIC
;  IN:	Nothing
; OUT:	Nothing, all registers preserved
net_virtio_reset:
	push rdi
	push rsi
	push rcx
	push rax

	; Device Initialization (section 3.1)

	mov rsi, [os_NetIOBaseMem]

	; 3.1.1 - Step 1 -  Reset the device (section 2.4)
	mov al, 0x00			
	mov [rsi+VIRTIO_DEVICE_STATUS], al
virtio_net_init_reset_wait:
	mov al, [rsi+VIRTIO_DEVICE_STATUS]
	cmp al, 0x00
	jne virtio_net_init_reset_wait

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
;	btc eax, VIRTIO_NET_F_MQ	; Disable Multiqueue support for this driver
;	bts eax, VIRTIO_NET_F_MAC
;	bts eax, VIRTIO_NET_F_STATUS
	mov eax, 0x00010020		; STATUS, MAC
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
	jnc virtio_net_init_error

	; 3.1.1 - Step 7
	; Set up the device and the queues
	; discovery of virtqueues for the device
	; optional per-bus setup
	; reading and possibly writing the device’s virtio configuration space
	; population of virtqueues

	mov ax, 0x0000
	mov [rsi+VIRTIO_CONFIG_MSIX_VECTOR], ax

	; Set up Queue 0
	xor eax, eax
	mov [rsi+VIRTIO_QUEUE_SELECT], ax
	mov ax, [rsi+VIRTIO_QUEUE_SIZE]	; Return the size of the queue
	mov ecx, eax			; Store queue size in ECX
	mov eax, os_net_mem
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
	mov ax, 0x0001
	mov [rsi+VIRTIO_QUEUE_MSIX_VECTOR], ax
	mov ax, [rsi+VIRTIO_QUEUE_MSIX_VECTOR]
	mov ax, 1
	mov [rsi+VIRTIO_QUEUE_ENABLE], ax

	; Set up Queue 1
	mov eax, 1
	mov [rsi+VIRTIO_QUEUE_SELECT], ax
	mov ax, [rsi+VIRTIO_QUEUE_SIZE]	; Return the size of the queue
	mov ecx, eax			; Store queue size in ECX
	mov eax, os_net_mem
	add eax, 16384
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

	; Populate the Next entries in the description rings
	; FIXME - Don't expect exactly 256 entries
	mov eax, 1
	mov rdi, os_net_mem
	add rdi, 14
virtio_net_init_pop:
	mov [rdi], al
	add rdi, 16384
	mov [rdi], al
	sub rdi, 16384
	add rdi, 16
	add al, 1
	cmp al, 0
	jne virtio_net_init_pop

	; Populate RX desc
	mov rdi, os_net_mem
	mov rax, os_PacketBuffers	; Address for storing the data
	stosq
	mov eax, 1500			; Number of bytes
	stosd
	mov ax, VIRTQ_DESC_F_WRITE
	stosw				; 16-bit Flags

	; Populate RX avail
	mov rdi, os_net_mem
	add rdi, 0x1000
	xor eax, eax
	stosw				; 16-bit flags
	mov ax, 1
	stosw				; 16-bit index
	mov ax, 0
	stosw				; 16-bit ring

	; 3.1.1 - Step 8 - At this point the device is “live”
	mov al, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_DRIVER_OK | VIRTIO_STATUS_FEATURES_OK
	mov [rsi+VIRTIO_DEVICE_STATUS], al

	pop rax
	pop rcx
	pop rsi
	pop rdi

	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_virtio_transmit - Transmit a packet via a Virtio NIC
;  IN:	RSI = Location of packet
;	RCX = Length of packet
; OUT:	Nothing
net_virtio_transmit:
	push rdi
	push rdx
	push rbx
	push rax

	; Create Descriptor entries
	mov rdi, 0x1a4000
	mov rax, netheader		; Address of the netheader
	stosq				; 64-bit address
	mov eax, 12
	stosd				; 32-bit length
	mov ax, VIRTQ_DESC_F_NEXT
	stosw				; 16-bit Flags
	add rdi, 2			; Skip Next as it is pre-populated
	mov rax, rsi			; Address of the data
	stosq
	mov eax, ecx			; Number of bytes
	stosd
	mov ax, 0
	stosw				; 16-bit Flags

	; Add entry to Avail
	mov rdi, 0x1a5000
	mov ax, 1			; 1 for no interrupts
	stosw				; 16-bit flags
	mov ax, [nettxavailindex]
	stosw				; 16-bit index
	mov ax, 0
	stosw				; 16-bit ring

	; Notify the queue
	mov rdi, [os_NetIOBaseMem]
	add rdi, [virtio_net_notify_offset]
	add rdi, 4
	xor eax, eax
	stosw

	; Inspect the used ring
	mov rdi, 0x1a6002		; Offset to start of Used Ring
	mov bx, [nettxavailindex]
net_virtio_transmit_wait:
	mov ax, [rdi]			; Load the index
	cmp ax, bx
	jne net_virtio_transmit_wait

	add word [nettxdescindex], 2	; 2 entries were required
	add word [nettxavailindex], 1

	pop rax
	pop rbx
	pop rdx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_virtio_poll - Polls the Virtio NIC for a received packet
;  IN:	RDI = Location to store packet
; OUT:	RCX = Length of packet
net_virtio_poll:
	push rdi
	push rsi
	push rax

	; Get size of packet that was received
	mov rdi, os_net_mem
	add rdi, 0x2000			; Offset to Used Ring
	xor eax, eax
	mov ax, [rdi+2]			; Offset to Used Ring Index
	shl eax, 3			; Quick multiply by 8
	add rdi, rax			; RDI points to the Used Ring Entry
	mov ax, [rdi]			; Load the received packet size
	mov cx, ax			; Save the packet size to CX for later
	cmp cx, 0
	je net_virtio_poll_nodata	; Bail out if there was no data

	; Add received packet size to start of os_PacketBuffers
	push rdi
	mov rdi, os_PacketBuffers
	mov rsi, os_PacketBuffers+0x0C	; Skip over the 12 byte Virtio header
	push cx
	rep movsb			; Copy the packet data
	pop cx
	xor eax, eax
	stosq				; Clear the end of the packet in os_PacketBuffers
	stosq
	pop rdi
	mov [rdi], ax			; Clear the Used Ring Entry

	; Re-populate RX desc
	mov rdi, os_net_mem
	mov rax, os_PacketBuffers	; Address for storing the data
	stosq
	mov eax, 1500			; Number of bytes
	stosd
	mov ax, VIRTQ_DESC_F_WRITE
	stosw				; 16-bit Flags

	; Populate RX avail
	mov rdi, os_net_mem
	add rdi, 0x1000
	xor eax, eax
	stosw				; 16-bit flags
	mov ax, [netrxavailindex]
	stosw				; 16-bit index
	mov ax, 0
	stosw				; 16-bit ring

	add word [netrxdescindex], 1
	add word [netrxavailindex], 1

net_virtio_poll_nodata:
	pop rax
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; Variables
virtio_net_notify_offset: dq 0
virtio_net_notify_offset_multiplier: dq 0
virtio_net_isr_offset: dq 0
virtio_net_device_offset: dq 0
netrxdescindex: dw 0
netrxavailindex: dw 0
nettxdescindex: dw 0
nettxavailindex: dw 1

align 16
netheader:
dd 0x00000000
dd 0x00000000
dd 0x00000000

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

; VIRTIO_NET_HDR flags
VIRTIO_NET_HDR_F_NEEDS_CSUM	equ 1
VIRTIO_NET_HDR_F_DATA_VALID	equ 2
VIRTIO_NET_HDR_F_RSC_INFO	equ 4

; VIRTIO_NET_HDR gso_type
VIRTIO_NET_HDR_GSO_NONE		equ 0
VIRTIO_NET_HDR_GSO_TCPV4	equ 1
VIRTIO_NET_HDR_GSO_UDP		equ 3
VIRTIO_NET_HDR_GSO_TCPV6	equ 4
VIRTIO_NET_HDR_GSO_UDP_L4	equ 5
VIRTIO_NET_HDR_GSO_ECN		equ 0x80

; =============================================================================
; EOF