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
	push rdi
	push rsi
	push rdx
	push rcx
	push rbx
	push rax

	mov rdi, net_table
	xor eax, eax
	mov al, [os_net_icount]
	shl eax, 7			; Quick multiply by 128
	add rdi, rax

	mov ax, 0x1AF4			; Driver tag for virtio-net
	stosw
	push rdi			; Used in msi-x init
	add rdi, 14

	; Get the Base Memory Address of the device
	mov al, 4			; Read BAR4
	call os_bus_read_bar
	stosq				; Save the base
	push rax			; Save the base for gathering the MAC later
	mov rax, rcx
	stosq				; Save the length

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
	pop rsi				; Pushed as RAX
	pop rdi
	add rdi, 6			; nt_MAC
	add rsi, [virtio_net_device_offset]
	mov ecx, 6
	rep movsb

	; Set base addresses for TX and RX descriptors
	xor ecx, ecx
	mov cl, byte [os_net_icount]
	shl ecx, 15
	add rdi, 0x22
	mov rax, os_tx_desc
	add rax, rcx
	stosq
	mov rax, os_rx_desc
	add rax, rcx
	stosq

	; Reset the device
	xor edx, edx
	mov dl, [os_net_icount]
	call net_virtio_reset

	; Store call addresses
	sub rdi, 0x28
	mov rax, net_virtio_config
	stosq
	mov rax, net_virtio_transmit
	stosq
	mov rax, net_virtio_poll
	stosq

virtio_net_init_error:
	pop rax
	pop rbx
	pop rcx
	pop rdx
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_virtio_reset - Reset a Virtio NIC
;  IN:	RDX = Interface ID
; OUT:	Nothing, all registers preserved
net_virtio_reset:
	push rdi
	push rsi
	push rcx
	push rax

	; Device Initialization (section 3.1)

	; Gather Base Address from net_table
	mov rsi, net_table
	xor eax, eax
	mov al, [os_net_icount]
	shl eax, 7			; Quick multiply by 128
	add rsi, rax
	mov r8, rsi			; Save table base address for this interface
	add rsi, 16
	mov rsi, [rsi]
	mov rdi, rsi

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
	xor eax, eax
	mov [rsi+VIRTIO_DRIVER_FEATURE_SELECT], eax
	mov eax, 0x00010020		; Feature bits 31:0 - STATUS (16), MAC (5)
	mov [rsi+VIRTIO_DRIVER_FEATURE], eax
	; Process the next 32-bits of Feature bits
	mov eax, 1
	mov [rsi+VIRTIO_DEVICE_FEATURE_SELECT], eax
	mov eax, [rsi+VIRTIO_DEVICE_FEATURE]
	mov eax, 1
	mov [rsi+VIRTIO_DRIVER_FEATURE_SELECT], eax
	; TODO - Check into how LEGACY affects the 12-byte header
	mov eax, 1			; Feature bits 63:32 - LEGACY (32)
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

	; Set up Queue 0 (Receive)
	xor eax, eax
	mov [rsi+VIRTIO_QUEUE_SELECT], ax
	mov ax, [rsi+VIRTIO_QUEUE_SIZE]	; Return the size of the queue
	mov [r8+0x7E], ax		; Store receive queue size in net_table
	mov ecx, eax			; Store receive queue size in ECX
	mov rax, [r8+nt_rx_desc]	; Set address of Descriptor ring
	mov [rsi+VIRTIO_QUEUE_DESC], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DESC+8], eax
	rol rax, 32
	add rax, 4096			; Set address of Available ring
	mov [rsi+VIRTIO_QUEUE_DRIVER], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DRIVER+8], eax
	rol rax, 32
	add rax, 4096			; Set address of Used ring
	mov [rsi+VIRTIO_QUEUE_DEVICE], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DEVICE+8], eax
	rol rax, 32
	mov ax, 0x0001
	mov [rsi+VIRTIO_QUEUE_MSIX_VECTOR], ax
	mov ax, [rsi+VIRTIO_QUEUE_MSIX_VECTOR]
	mov ax, 1
	mov [rsi+VIRTIO_QUEUE_ENABLE], ax

	; Set up Queue 1 (Transmit)
	mov eax, 1
	mov [rsi+VIRTIO_QUEUE_SELECT], ax
	mov ax, [rsi+VIRTIO_QUEUE_SIZE]	; Return the size of the queue
	mov [r8+0x7C], ax		; Store transmit queue size in net_table
	mov ecx, eax			; Store transmit queue size in ECX
	mov rax, [r8+nt_tx_desc]	; Set address of Descriptor ring
	mov [rsi+VIRTIO_QUEUE_DESC], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DESC+8], eax
	rol rax, 32
	add rax, 4096			; Set address of Available ring
	mov [rsi+VIRTIO_QUEUE_DRIVER], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DRIVER+8], eax
	rol rax, 32
	add rax, 4096			; Set address of Used ring
	mov [rsi+VIRTIO_QUEUE_DEVICE], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DEVICE+8], eax
	rol rax, 32
	mov ax, 1
	mov [rsi+VIRTIO_QUEUE_ENABLE], ax

	; Populate TX Descriptor Table Entries
	mov eax, 1
	mov rdi, [r8+nt_tx_desc]
	add rdi, 14
virtio_net_init_pop_tx_d:
	mov [rdi], al
	add rdi, 16
	add al, 1
	cmp al, 0
	jne virtio_net_init_pop_tx_d

	; Populate RX Descriptor Table Entries
	xor ecx, ecx
	mov rdi, [r8+nt_rx_desc]
	mov rbx, [os_PacketBase]
virtio_net_init_pop_rx_d:
	mov rax, rbx			; 64-bit Address
	add rbx, 2048
	stosq
	mov eax, 2048			; 32-bit Length
	stosd
	mov ax, VIRTQ_DESC_F_WRITE
	stosw				; 16-bit Flags
	inc cl
	mov ax, 0
	stosw				; 16-bit Next
	cmp cl, 0
	jne virtio_net_init_pop_rx_d
	mov [os_PacketBase], rbx

	; Populate RX Available Ring Entries
	mov rdi, [r8+nt_rx_desc]
	add rdi, 0x1000
	xor eax, eax
	stosw				; 16-bit flags
	mov ax, [r8+0x7C]		; Gather queue size
	dec ax				; Mark all descriptors (minus 1) as available
	stosw				; 16-bit index
	xor eax, eax
virtio_net_init_pop_rx_a:
	stosw				; 16-bit ring
	inc al
	cmp al, 0
	jne virtio_net_init_pop_rx_a

	; Set nettxavailindex
	mov ax, 1
	mov [r8+0x76], ax

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
; net_virtio_config -
;  IN:	RAX = Base address to store packets
;	RDX = Interface ID
; OUT:	Nothing
net_virtio_config:
	push rdi
	push rcx
	push rax

	mov rdi, [rdx+nt_rx_desc]	; Gather offset to device RX descriptors
	mov ecx, 256
	call os_virt_to_phys		; Convert (potentially) virtual address
net_virtio_config_next_record:
	stosq				; Store address
	add rdi, 8			; Skip to next entry
	add rax, 2048			; Add 2048 to address
	dec ecx
	cmp ecx, 0
	jnz net_virtio_config_next_record

	pop rax
	pop rcx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_virtio_transmit - Transmit a packet via a Virtio NIC
;  IN:	RSI = Location of packet
;	RDX = Interface ID
;	RCX = Length of packet
; OUT:	Nothing
net_virtio_transmit:
	push r8
	push rdi
	push rdx
	push rbx
	push rax

	mov r8, [rdx+nt_tx_desc]

	; Create first entry in the Descriptor Table
	mov rdi, r8
	mov rax, virtio_net_hdr		; Address of the 12-byte virtio_net_hdr
	stosq				; 64-bit address
	mov eax, 12
	stosd				; 32-bit length
	mov ax, VIRTQ_DESC_F_NEXT	; Set flag so next descriptor will be processed as well
	stosw				; 16-bit Flags
	add rdi, 2			; Skip 16-bit Next as it is pre-populated

	; Create second entry in the Descriptor Table
	mov rax, rsi			; Address of the data
	stosq
	mov eax, ecx			; Number of bytes
	stosd
	mov ax, 0
	stosw				; 16-bit Flags
	stosw				; 16-bit Next

	; Add entry to the Available Ring
	mov rdi, r8
	add rdi, 0x1000			; TODO - gather this value
	mov ax, 1			; 1 for no interrupts
	stosw				; 16-bit Flags
	mov ax, [rdx+0x76]		; nettxavailindex
	stosw				; 16-bit Index
	mov ax, 0
	stosw				; 16-bit Ring

	; Notify the queue
	mov rdi, [rdx+nt_base]		; Transmit Descriptor Base Address
	add rdi, [virtio_net_notify_offset]
	add rdi, 4
	xor eax, eax
	stosw

	; Inspect the Used Ring
	mov rdi, r8
	; TODO should flags be checked?
	add rdi, 0x2002			; Offset to start of Used Ring Index
	mov bx, [rdx+0x76]		; nettxavailindex
net_virtio_transmit_wait:
	mov ax, [rdi]			; Load the index
	cmp ax, bx
	jne net_virtio_transmit_wait

	add word [rdx+0x74], 2		; nettxdescindex - 2 descriptor entries were required
	add word [rdx+0x76], 1		; nettxavailindex

	pop rax
	pop rbx
	pop rdx
	pop rdi
	pop r8
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_virtio_poll - Polls the Virtio NIC for a received packet
;  IN:	RDX = Interface ID
; OUT:	RDI = Location of stored packet
;	RCX = Length of packet
net_virtio_poll:
	push r8
	push rsi
	push rbx
	push rax

	; Gather info from driver info
	mov r8, [rdx+nt_rx_desc]
	mov bx, [rdx+0x7E]		; Receive queue size
	dec bx				; Ex: 0x100 becomes 0xFF

	; Check if the Used Ring Index has changed from the last known value
	mov rdi, r8
	add rdi, 0x2000			; Offset to Used Ring
	xor eax, eax
	mov ax, [rdi+2]			; Load Used Ring Index
	and ax, bx
	cmp ax, [rdx+0x78]		; Check against the last known index value
	je net_virtio_poll_nodata	; If equal then bail out

	; Get size of packet that was received
	mov ax, [rdx+0x78]		; Get last known Used Ring Index
	shl eax, 3			; Quick multiply by 8
	add eax, 4			; Add offset to entries (skip 16-bit Flags and 16-bit Index)
	add rdi, rax			; RDI points to the Used Ring Entry
	mov rcx, [rdi]			; Load the 32-bit ID (low bits) and 32-bit Length (high bits) together

	; Populate RX Available Ring
	mov rdi, r8
	add rdi, 0x1002			; Add offset to the Available Ring
	mov ax, [rdi]			; 16-bit Index
	inc ax				; 65535 will wrap back around to 0
	mov [rdi], ax			; 16-bit Index

	; Set RDI to address of packet
	xor eax, eax
	mov eax, ecx			; Lower 32 bits of RCX contains the Used Ring Entry Address
	shl rax, 4			; Quick multiply by 16 as each Descriptor Table Entry is 16 bytes
	mov rdi, r8			; Set RDI to the address of the Descriptor Table
	add rdi, rax			; Add entry offset into Descriptor Table
	mov rdi, [rdi]			; Load memory address
	add rdi, 12			; Skip past the virtio-net header

	; Set RCX to just the packet length
	shr rcx, 32			; Shift upper 32 bits to the lower 32
	sub cx, 12			; Subtract the virtio-net header

	; Increment internal counters
	mov ax, [rdx+0x78]		; lastrx
	inc ax
	and ax, bx			; Wrap back to 0 if greater than queue length
	mov [rdx+0x78], ax		; lastrx

net_virtio_poll_nodata:
	pop rax
	pop rbx
	pop rsi
	pop r8
	ret
; -----------------------------------------------------------------------------


; Variables
virtio_net_notify_offset: dq 0
virtio_net_notify_offset_multiplier: dq 0
virtio_net_isr_offset: dq 0
virtio_net_device_offset: dq 0

align 16
virtio_net_hdr:
flags: db 0x00
gso_type: db 0x00
hdr_len: dw 0x0000
gso_size: dw 0x0000
csum_start: dw 0x0000
csum_offset: dw 0x0000
num_buffers: dw 0x0000

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