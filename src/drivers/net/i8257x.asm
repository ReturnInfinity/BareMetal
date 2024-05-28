; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; Intel 8257x Gigabit Ethernet Driver
; =============================================================================


; -----------------------------------------------------------------------------
; Initialize an Intel 8254x NIC
;  IN:	RDX = Packed Bus address (as per syscalls/bus.asm)
net_i8257x_init:
	push rsi
	push rdx
	push rcx
	push rbx
	push rax

	; Grab the Base I/O Address of the device
	xor ebx, ebx
	mov dl, 0x04				; Read register 4 for BAR0
	call os_bus_read
	xchg eax, ebx				; Exchange the result to EBX (low 32 bits of base)
	bt ebx, 0				; Bit 0 will be 0 if it is an MMIO space
	jc net_i8257x_init_error
	bt ebx, 2				; Bit 2 will be 1 if it is a 64-bit MMIO space
	jnc net_i8257x_init_32bit_bar
	mov dl, 0x05				; Read register 5 for BAR1 (Upper 32-bits of BAR0)
	call os_bus_read
	shl rax, 32				; Shift the bits to the upper 32
net_i8257x_init_32bit_bar:
	and ebx, 0xFFFFFFF0			; Clear the low four bits
	add rax, rbx				; Add the upper 32 and lower 32 together
	mov [os_NetIOBaseMem], rax		; Save it as the base

	; Grab the IRQ of the device
	mov dl, 0x0F				; Get device's IRQ number from Bus Register 15 (IRQ is bits 7-0)
	call os_bus_read
	mov [os_NetIRQ], al			; AL holds the IRQ

	; Disable INTX
	mov dl, 0x01				; Read Status/Command
	call os_bus_read
	bts eax, 10				; Set Interrupt Disable (bit 10)
	call os_bus_write

	; Enable PCI Bus Mastering and Memory Space
	mov dl, 0x01				; Get Status/Command
	call os_bus_read
	bts eax, 2				; Bus Master Enable Bit
	bts eax, 1				; Memory Space Enable Bit
	call os_bus_write

	; Grab the MAC address
	mov rsi, [os_NetIOBaseMem]
	mov eax, [rsi+0x5400]			; RAL
	mov [os_NetMAC], al
	shr eax, 8
	mov [os_NetMAC+1], al
	shr eax, 8
	mov [os_NetMAC+2], al
	shr eax, 8
	mov [os_NetMAC+3], al
	mov eax, [rsi+0x5404]			; RAH
	mov [os_NetMAC+4], al
	shr eax, 8
	mov [os_NetMAC+5], al

	; Reset the device
	call net_i8257x_reset

net_i8257x_init_error:

	pop rax
	pop rbx
	pop rcx
	pop rdx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8257x_reset - Reset an Intel 8254x NIC
;  IN:	Nothing
; OUT:	Nothing, all registers preserved
net_i8257x_reset:
	push rdi
	push rsi
	push rax

	mov rsi, [os_NetIOBaseMem]
	mov rdi, rsi

	; Disable Interrupts (14.4)
	xor eax, eax
	mov [rsi+i8257x_IMS], eax
	mov eax, i8257x_IRQ_CLEAR_MASK
	mov [rsi+i8257x_IMC], eax
	mov eax, [rsi+i8257x_ICR]
	
	; Issue a global reset (14.5)
	mov eax, i8257x_CTRL_RST_MASK		; Load the mask for a software reset and link reset
	mov [rsi+i8257x_CTRL], eax		; Write the reset value
net_i8257x_init_reset_wait:
	mov eax, [rsi+i8257x_CTRL]		; Read CTRL
	jnz net_i8257x_init_reset_wait		; Wait for it to read back as 0x0

	; Disable Interrupts again (14.4)
	xor eax, eax
	mov [rsi+i8257x_IMS], eax
	mov eax, i8257x_IRQ_CLEAR_MASK
	mov [rsi+i8257x_IMC], eax
	mov eax, [rsi+i8257x_ICR]

	; Set up the PHY and the link (14.8.1)

	; Initialize all statistical counters ()
	mov eax, [rsi+i8257x_GPRC]		; RX packets
	mov eax, [rsi+i8257x_GPTC]		; TX packets
	mov eax, [rsi+i8257x_GORCL]
	mov eax, [rsi+i8257x_GORCH]		; RX bytes = GORCL + (GORCH << 32)
	mov eax, [rsi+i8257x_GOTCL]
	mov eax, [rsi+i8257x_GOTCH]		; TX bytes = GOTCL + (GOTCH << 32)

	; Initialize receive (14.6)
	
	; Initialize transmit (14.7)

	; Enable interrupts ()

	; Set Driver Loaded bit
	mov eax, [rsi+i8257x_CTRL_EXT]
	or eax, 1 << i8257x_CTRL_EXT_DRV_LOAD
	mov [rsi+i8257x_CTRL_EXT], eax

	pop rax
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8257x_transmit - Transmit a packet via an Intel 8254x NIC
;  IN:	RSI = Location of packet
;	RCX = Length of packet
; OUT:	Nothing
; Note:	This driver uses the "legacy format" so TDESC.DEXT is set to 0
;	Descriptor Format:
;	Bytes 7:0 - Buffer Address
;	Bytes 9:8 - Length
;	Bytes 13:10 - Flags
;	Bytes 15:14 - Special
net_i8257x_transmit:
	push rdi
	push rax

	pop rax
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8257x_poll - Polls the Intel 8254x NIC for a received packet
;  IN:	RDI = Location to store packet
; OUT:	RCX = Length of packet
; Note:	Descriptor Format:
;	Bytes 7:0 - Buffer Address
;	Bytes 9:8 - Length
;	Bytes 13:10 - Flags
;	Bytes 15:14 - Special
net_i8257x_poll:
	push rdi
	push rsi
	push rax

	pop rax
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8257x_ack_int - Acknowledge an internal interrupt of the Intel 8254x NIC
;  IN:	Nothing
; OUT:	RAX = Ethernet status
net_i8257x_ack_int:
	push rdi

	pop rdi
	ret
; -----------------------------------------------------------------------------


; Maximum packet size
I8257X_MAX_PKT_SIZE	equ 16384

; Register list (All registers should be accessed as 32-bit values)

; General Control Registers
i8257x_CTRL		equ 0x00000 ; Device Control Register
i8257x_CTRL_Legacy	equ 0x00004 ; Copy of Device Control Register
i8257x_STATUS		equ 0x00008 ; Device Status Register
i8257x_CTRL_EXT		equ 0x00018 ; Extended Device Control Register
i8257x_LEDCTL		equ 0x00E00 ; LED Control

; EEPROM / Flash Registers

; Interrupts Registers
i8257x_ICR		equ 0x000C0 ; Interrupt Cause Read
i8257x_ICS		equ 0x000C8 ; Interrupt Cause Set
i8257x_IMS		equ 0x000D0 ; Interrupt Mask Set/Read
i8257x_IMC		equ 0x000D8 ; Interrupt Mask Clear
i8257x_IAM		equ 0x000E0 ; Interrupt Acknowledge Auto Mask

; Receive Registers
i8257x_RCTL		equ 0x00100 ; Receive Control
i8257x_RDBAL		equ 0x02800 ; Receive Descriptor Base Address Low Queue 0
i8257x_RDBAH		equ 0x02804 ; Receive Descriptor Base Address High Queue 0
i8257x_RDLEN		equ 0x02808 ; Receive Descriptor Ring Length Queue 0
i8257x_RDH		equ 0x02810 ; Receive Descriptor Head Queue 0
i8257x_RDT		equ 0x02818 ; Receive Descriptor Tail Queue 0
i8257x_RXDCTL		equ 0x02828 ; Receive Descriptor Control Queue 0
i8257x_RXCSUM		equ 0x05000 ; Receive Checksum Control
i8257x_RLPML		equ 0x05004 ; Receive Long packet maximal length
i8257x_RFCTL		equ 0x05008 ; Receive Filter Control Register
i8257x_MTA		equ 0x05200 ; Multicast Table Array (n)
i8257x_RAL		equ 0x05400 ; Receive Address Low (Lower 32-bits of 48-bit address)
i8257x_RAH		equ 0x05404 ; Receive Address High (Upper 16-bits of 48-bit address). Bit 31 should be set for Address Valid

; Transmit Registers
i8257x_TCTL		equ 0x00400 ; Transmit Control
i8257x_TDBAL		equ 0x03800 ; Transmit Descriptor Base Address Low
i8257x_TDBAH		equ 0x03804 ; Transmit Descriptor Base Address High
i8257x_TDLEN		equ 0x03808 ; Transmit Descriptor Length (Bits 19:0 in bytes, 128-byte aligned)
i8257x_TDH		equ 0x03810 ; Transmit Descriptor Head (Bits 15:0)
i8257x_TDT		equ 0x03818 ; Transmit Descriptor Tail (Bits 15:0)
i8257x_TXDCTL		equ 0x03828 ; Transmit Descriptor Control (Bit 25 - Enable)

; Statistic Registers
i8257x_GPRC		equ 0x04074 ; Good Packets Received Count
i8257x_BPRC		equ 0x04078 ; Broadcast Packets Received Count
i8257x_MPRC		equ 0x0407C ; Multicast Packets Received Count
i8257x_GPTC		equ 0x04080 ; Good Packets Transmitted Count
i8257x_GORCL		equ 0x04088 ; Good Octets Received Count Low
i8257x_GORCH		equ 0x0408C ; Good Octets Received Count High
i8257x_GOTCL		equ 0x04090 ; Good Octets Transmitted Count Low
i8257x_GOTCH		equ 0x04094 ; Good Octets Transmitted Count High




; CTRL (Device Control Register, 0x00000 / 0x00004, RW) Bit Masks
i8257x_CTRL_LRST	equ 3 ; Link Reset
i8257x_CTRL_RST		equ 26 ; Device Reset
; All other bits are reserved and should be written as 0
i8257x_CTRL_RST_MASK	equ 1 << i8259x_CTRL_LRST | 1 << i8259x_CTRL_RST

; CTRL_EXT (Extended Device Control Register, 0x00018, RW) Bit Masks
i8257x_CTRL_EXT_DRV_LOAD	equ 28 ; Driver loaded and the corresponding network interface is enabled

i8257x_IRQ_CLEAR_MASK	equ 0xFFFFFFFF

; =============================================================================
; EOF