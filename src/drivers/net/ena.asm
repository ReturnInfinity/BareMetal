; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Elastic Network Adapter Driver
; =============================================================================


; -----------------------------------------------------------------------------
; Initialize an ENA NIC
;  IN:	RDX = Packed Bus address (as per syscalls/bus.asm)
net_ena_init:
	push rdi
	push rsi
	push rdx
	push rcx
	push rax

	mov rdi, net_table
	xor eax, eax
	mov al, [os_net_icount]
	shl eax, 7			; Quick multiply by 128
	add rdi, rax

	mov ax, 0x0EC2			; Driver tag for ena
	mov [rdi+nt_ID], ax

	; Get the Base Memory Address of the device
	mov al, 0			; Read BAR0
	call os_bus_read_bar
	mov [rdi+nt_base], rax		; Save the base
	push rax			; Save the base for gathering the MAC later

	; Set PCI Status/Command values
	mov dl, 0x01			; Read Status/Command
	call os_bus_read
	bts eax, 10			; Set Interrupt Disable
	bts eax, 2			; Enable Bus Master
	bts eax, 1			; Enable Memory Space
	call os_bus_write		; Write updated Status/Command

	; Usually the MAC would be read from the device MMIO here but ENA works differently

	; Set base addresses for TX and RX descriptors
	xor ecx, ecx
	mov cl, byte [os_net_icount]
	shl ecx, 15

	mov rax, os_tx_desc
	add rax, rcx
	mov [rdi+nt_tx_desc], rax
	mov rax, os_rx_desc
	add rax, rcx
	mov [rdi+nt_rx_desc], rax

	; Reset the device
	xor edx, edx
	mov dl, [os_net_icount]
	call net_ena_reset

	; Store call addresses
	mov rax, net_ena_config
	mov [rdi+nt_config], rax
	mov rax, net_ena_transmit
	mov [rdi+nt_transmit], rax
	mov rax, net_ena_poll
	mov [rdi+nt_poll], rax

net_ena_init_error:

	pop rax
	pop rcx
	pop rdx
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_ena_reset - Reset an ENA NIC
;  IN:	RDX = Interface ID
; OUT:	Nothing, all registers preserved
net_ena_reset:
	push rdi
	push rsi
	push rax

	; Gather Base Address from net_table
	mov rsi, net_table
	xor eax, eax
	mov al, [os_net_icount]
	shl eax, 7			; Quick multiply by 128
	add rsi, rax
	add rsi, 16
	mov rsi, [rsi]
	mov rdi, rsi

	; Stop queues if they are running

	; Reset interface
	mov eax, 1			; Set the bit for ENA_CTRL_RESET
	mov [rsi+ENA_DEV_CTL], eax

	; Wait for reset
net_ena_reset_wait:
	mov eax, [rsi+ENA_DEV_STS]	; Read the current controller status
	bt eax, 3			; Put bit 3 into carry flag
	jc net_ena_reset_wait		; Keep polling until carry is clear (reset completed)

	; Clear reset
	xor eax, eax			; Clear the ENA_CTRL_RESET bit we set earlier
	mov [rsi+ENA_DEV_CTL], eax

	; Wait for reset clear
net_ena_reset_wait_clear:
	mov eax, [rsi+ENA_DEV_STS]	; Read the current controller status
	bt eax, 3			; Put bit 3 into carry flag
	jnc net_ena_reset_wait_clear	; Keep polling until carry is set

	; Check ENA_DEV_STS.READY
	mov eax, [rsi+ENA_DEV_STS]
	test eax, 1
	; poll bit with timeout

	; Check versions
	mov eax, [rsi+ENA_VERSION]
	mov eax, [rsi+ENA_CONTROLLER_VERSION]

	; Check capabilities
	mov eax, [rsi+ENA_CAPS]
	mov eax, [rsi+ENA_CAPS_EXT]

	; Set device memory
	mov rax, 0x600000
	mov [rsi+ENA_AQ_BASE_LO], eax
	shr rax, 32
	mov [rsi+ENA_AQ_BASE_HI], eax
	mov rax, 0x610000
	mov [rsi+ENA_ACQ_BASE_LO], eax
	shr rax, 32
	mov [rsi+ENA_ACQ_BASE_HI], eax
	mov rax, 0x620000
	mov [rsi+ENA_AENQ_BASE_LO], eax
	shr rax, 32
	mov [rsi+ENA_AENQ_BASE_HI], eax

	; Create Admin Queues
	; Admin Submission Queue (AQ)
	; Admin Completion Queue (ACQ)

	; Check ENA_DEV_STS.READY

	; Build an Admin command
	; opcode ENA_ADMIN_GET_FEATURE = 0x0008
	; feat_id ENA_ADMIN_DEVICE_ATTRIBUTES = 1
	; Put it in the queue
	; Wait for completion
	; Check head has changed
	; Verify command
	; Verify status (ENA_ADMIN_SUCCESS)
	; MAC Address at offset 0x0 of returned data

	pop rax
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_ena_config -
;  IN:	RAX = Base address to store packets
;	RDX = Interface ID
; OUT:	Nothing
net_ena_config:
	push rdi
	push rcx
	push rax

	pop rax
	pop rcx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_ena_transmit - Transmit a packet via an ENA NIC
;  IN:	RSI = Location of packet
;	RDX = Interface ID
;	RCX = Length of packet
; OUT:	Nothing
net_ena_transmit:
	push rdi
	push rbx
	push rax

	mov rdi, [rdx+nt_tx_desc]	; Transmit Descriptor Base Address

	pop rax
	pop rbx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_ena_poll - Polls the ENA NIC for a received packet
;  IN:	RDX = Interface ID
; OUT:	RDI = Location of stored packet
;	RCX = Length of packet
net_ena_poll:
	push rsi			; Used for the base MMIO of the NIC
	push rbx
	push rax

	mov rdi, [rdx+nt_rx_desc]
	mov rsi, [rdx+nt_base]		; Load the base MMIO of the NIC

net_ena_poll_end:
	pop rax
	pop rbx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_ena_ack_int - Acknowledge an internal interrupt of the Intel 8254x NIC
;  IN:	Nothing
; OUT:	RAX = Ethernet status
;net_ena_ack_int:
;	push rdi
;
;	pop rdi
;	ret
; -----------------------------------------------------------------------------


; Register list (All registers should be accessed as 32-bit values)

; General Control Registers

ENA_VERSION			equ 0x00
ENA_CONTROLLER_VERSION		equ 0x04
ENA_CAPS			equ 0x08
ENA_CAPS_EXT			equ 0x0C
ENA_AQ_BASE_LO			equ 0x10
ENA_AQ_BASE_HI			equ 0x14
ENA_AQ_CAPS			equ 0x18
ENA_ACQ_BASE_LO			equ 0x20
ENA_ACQ_BASE_HI			equ 0x24
ENA_ACQ_CAPS			equ 0x28
ENA_AQ_DB			equ 0x2C
ENA_ACQ_TAIL			equ 0x30
ENA_AENQ_CAPS			equ 0x34
ENA_AENQ_BASE_LO		equ 0x38
ENA_AENQ_BASE_HI		equ 0x3C
ENA_AENQ_HEAD_DB		equ 0x40
ENA_AENQ_TAIL			equ 0x44
ENA_INTR_MASK			equ 0x4C
ENA_DEV_CTL			equ 0x54
ENA_DEV_STS			equ 0x58
ENA_MMIO_REG_READ		equ 0x5C
ENA_MMIO_RESP_LO		equ 0x60
ENA_MMIO_RESP_HI		equ 0x64
ENA_RSS_IND_ENTRY_UPDATE	equ 0x68

; Admin Queue Opcodes
ENA_ADMIN_CREATE_SQ		equ 1
ENA_ADMIN_DESTROY_SQ		equ 2
ENA_ADMIN_CREATE_CQ		equ 3
ENA_ADMIN_DESTROY_CQ		equ 4
ENA_ADMIN_GET_FEATURE		equ 8
ENA_ADMIN_SET_FEATURE		equ 9
ENA_ADMIN_GET_STATS		equ 11

; Admin Queue Status
ENA_ADMIN_SUCCESS			equ 0
ENA_ADMIN_RESOURCE_ALLOCATION_FAILURE	equ 1
ENA_ADMIN_BAD_OPCODE			equ 2
ENA_ADMIN_UNSUPPORTED_OPCODE		equ 3
ENA_ADMIN_MALFORMED_REQUEST		equ 4
ENA_ADMIN_ILLEGAL_PARAMETER		equ 5
ENA_ADMIN_UNKNOWN_ERROR			equ 6
ENA_ADMIN_RESOURCE_BUSY			equ 7

; Admin Queue Feature ID
ENA_ADMIN_DEVICE_ATTRIBUTES		equ 1
ENA_ADMIN_MAX_QUEUES_NUM		equ 2
ENA_ADMIN_HW_HINTS			equ 3
ENA_ADMIN_LLQ				equ 4
ENA_ADMIN_MAX_QUEUES_EXT		equ 7
ENA_ADMIN_RSS_HASH_FUNCTION		equ 10
ENA_ADMIN_STATELESS_OFFLOAD_CONFIG	equ 11
ENA_ADMIN_RSS_INDIRECTION_TABLE_CONFIG	equ 12
ENA_ADMIN_MTU				equ 14
ENA_ADMIN_RSS_HASH_INPUT		equ 18
ENA_ADMIN_INTERRUPT_MODERATION		equ 20
ENA_ADMIN_AENQ_CONFIG			equ 26
ENA_ADMIN_LINK_CONFIG			equ 27
ENA_ADMIN_HOST_ATTR_CONFIG		equ 28
ENA_ADMIN_FEATURES_OPCODE_NUM		equ 32

; Speeds
ENA_ADMIN_LINK_SPEED_1G			equ 0x1
ENA_ADMIN_LINK_SPEED_2_HALF_G		equ 0x2
ENA_ADMIN_LINK_SPEED_5G			equ 0x4
ENA_ADMIN_LINK_SPEED_10G		equ 0x8
ENA_ADMIN_LINK_SPEED_25G		equ 0x10
ENA_ADMIN_LINK_SPEED_40G		equ 0x20
ENA_ADMIN_LINK_SPEED_50G		equ 0x40
ENA_ADMIN_LINK_SPEED_100G		equ 0x80
ENA_ADMIN_LINK_SPEED_200G		equ 0x100
ENA_ADMIN_LINK_SPEED_400G		equ 0x200

; Register bits



; =============================================================================
; EOF
