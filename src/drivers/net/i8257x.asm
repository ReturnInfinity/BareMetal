; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Intel 8257x Gigabit Ethernet Driver
;
; This driver has been tested on physical hardware with a 82574L PCIe card
; (device ID 0x10D3) as well as QEMU (-device e1000e)
; =============================================================================


; -----------------------------------------------------------------------------
; Initialize an Intel 8257x NIC
;  IN:	RDX = Packed Bus address (as per syscalls/bus.asm)
net_i8257x_init:
	push rsi
	push rdx
	push rcx
	push rax

	; Get the Base Memory Address of the device
	mov al, 0			; Read BAR0
	call os_bus_read_bar
	mov [os_NetIOBaseMem], rax	; Save it as the base
	mov [os_NetIOLength], rcx	; Save the length

	; Set PCI Status/Command values
	mov dl, 0x01			; Read Status/Command
	call os_bus_read
	bts eax, 10			; Set Interrupt Disable
	bts eax, 2			; Enable Bus Master
	bts eax, 1			; Enable Memory Space
	call os_bus_write		; Write updated Status/Command

	; Get the MAC address
	mov rsi, [os_NetIOBaseMem]
	mov eax, [rsi+i8257x_RAL]	; RAL
	mov [os_NetMAC], al
	shr eax, 8
	mov [os_NetMAC+1], al
	shr eax, 8
	mov [os_NetMAC+2], al
	shr eax, 8
	mov [os_NetMAC+3], al
	mov eax, [rsi+i8257x_RAH]	; RAH
	mov [os_NetMAC+4], al
	shr eax, 8
	mov [os_NetMAC+5], al

	; Reset the device
	call net_i8257x_reset

net_i8257x_init_error:

	pop rax
	pop rcx
	pop rdx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8257x_reset - Reset an Intel 8257x NIC
;  IN:	Nothing
; OUT:	Nothing, all registers preserved
net_i8257x_reset:
	push rdi
	push rsi
	push rax

	mov rsi, [os_NetIOBaseMem]
	mov rdi, rsi

	; Disable Interrupts (14.4)
	mov eax, i8257x_IRQ_CLEAR_MASK
	mov [rsi+i8257x_IMC], eax	; Disable all interrupt causes
	xor eax, eax
	mov [rsi+i8257x_ITR], eax	; Disable interrupt throttling logic
	mov [rsi+i8257x_IMS], eax	; Mask all interrupts
	mov eax, [rsi+i8257x_ICR]	; Clear any pending interrupts

	; Issue a global reset (14.5)
	mov eax, i8257x_CTRL_RST_MASK	; Load the mask for a software reset and link reset
	mov [rsi+i8257x_CTRL], eax	; Write the reset value
net_i8257x_init_reset_wait:
	mov eax, [rsi+i8257x_CTRL]	; Read CTRL
	jnz net_i8257x_init_reset_wait	; Wait for it to read back as 0x0

	; Disable Interrupts again (14.4)
	mov eax, i8257x_IRQ_CLEAR_MASK
	mov [rsi+i8257x_IMC], eax	; Disable all interrupt causes
	xor eax, eax
	mov [rsi+i8257x_ITR], eax	; Disable interrupt throttling logic
	mov [rsi+i8257x_IMS], eax	; Mask all interrupts
	mov eax, [rsi+i8257x_ICR]	; Clear any pending interrupts

	; Set up the PHY and the link (14.8.1)
	mov eax, [rsi+i8257x_CTRL]
	; Clear the bits we don't want
	and eax, 0xFFFFFFFF - (1 << i8257x_CTRL_LRST | 1 << i8257x_CTRL_VME)
	; Set the bits we do want
	or eax, 1 << i8257x_CTRL_FD | 1 << i8257x_CTRL_SLU
	mov [rsi+i8257x_CTRL], eax

	; Initialize all statistical counters ()
	mov eax, [rsi+i8257x_GPRC]	; RX packets
	mov eax, [rsi+i8257x_GPTC]	; TX packets
	mov eax, [rsi+i8257x_GORCL]
	mov eax, [rsi+i8257x_GORCH]	; RX bytes = GORCL + (GORCH << 32)
	mov eax, [rsi+i8257x_GOTCL]
	mov eax, [rsi+i8257x_GOTCH]	; TX bytes = GOTCL + (GOTCH << 32)

	; Create RX descriptors
	push rdi
	mov ecx, i8257x_MAX_DESC
	mov rdi, os_rx_desc
net_i8257x_reset_nextdesc:	
	mov rax, os_PacketBuffers	; Default packet will go here
	stosq
	xor eax, eax
	stosq
	dec ecx
	jnz net_i8257x_reset_nextdesc
	pop rdi

	; Initialize receive (14.6)
	mov rax, os_rx_desc
	mov [rsi+i8257x_RDBAL], eax	; Receive Descriptor Base Address Low
	shr rax, 32
	mov [rsi+i8257x_RDBAH], eax	; Receive Descriptor Base Address High
	mov eax, i8257x_MAX_DESC * 16
	mov [rsi+i8257x_RDLEN], eax	; Receive Descriptor Length
	xor eax, eax
	mov [rsi+i8257x_RDH], eax	; Receive Descriptor Head
	mov eax, i8257x_MAX_DESC / 2
	mov [rsi+i8257x_RDT], eax	; Receive Descriptor Tail
	mov eax, 1 << i8257x_RCTL_EN | 1 << i8257x_RCTL_UPE | 1 << i8257x_RCTL_MPE | 1 << i8257x_RCTL_LPE | 1 << i8257x_RCTL_BAM | 1 << i8257x_RCTL_SECRC
	mov [rsi+i8257x_RCTL], eax	; Receive Control Register

	; Initialize transmit (14.7)
	mov rax, os_tx_desc
	mov [rsi+i8257x_TDBAL], eax	; Transmit Descriptor Base Address Low
	shr rax, 32
	mov [rsi+i8257x_TDBAH], eax	; Transmit Descriptor Base Address High
	mov eax, i8257x_MAX_DESC * 16
	mov [rsi+i8257x_TDLEN], eax	; Transmit Descriptor Length
	xor eax, eax
	mov [rsi+i8257x_TDH], eax	; Transmit Descriptor Head
	mov [rsi+i8257x_TDT], eax	; Transmit Descriptor Tail
	mov eax, 1 << i8257x_TCTL_EN | 1 << i8257x_TCTL_PSP | 15 << i8257x_TCTL_CT | 0x3F << i8257x_TCTL_COLD
	mov [rsi+i8257x_TCTL], eax	; Transmit Control Register

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
; net_i8257x_transmit - Transmit a packet via an Intel 8257x NIC
;  IN:	RSI = Location of packet
;	RCX = Length of packet
; OUT:	Nothing
; Note:	This driver uses the "legacy format" so TDESC.CMD.DEXT (5) is cleared to 0
;	TDESC Descriptor Format:
;	First Qword:
;	Bits 63:0 - Buffer Address
;	Second Qword:
;	Bits 15:0 - Length
;	Bits 23:16 - CSO - Checksum Offset
;	Bits 31:24 - CMD - Command Byte
;	Bits 35:32 - STA - Status
;	Bits 39:36 - ExtCMD - Extended Command
;	Bits 47:40 - CSS - Checksum Start
;	Bits 63:48 - VLAN
net_i8257x_transmit:
	push rdi
	push rax

	mov rdi, os_tx_desc		; Transmit Descriptor Base Address

	; Calculate the descriptor to write to
	mov eax, [i8257x_tx_lasttail]
	push rax			; Save lasttail
	shl eax, 4			; Quick multiply by 16
	add rdi, rax			; Add offset to RDI

	; Write to the descriptor
	mov rax, rsi
	stosq				; Store the data location
	mov rax, rcx			; The packet size is in CX
	bts rax, 24			; TDESC.CMD.EOP (0) - End Of Packet
	bts rax, 25			; TDESC.CMD.IFCS (1) - Insert FCS (CRC)
	bts rax, 27			; TDESC.CMD.RS (3) - Report Status
	stosq

	; Increment i8257x_tx_lasttail and the Transmit Descriptor Tail
	pop rax				; Restore lasttail
	add eax, 1
	and eax, i8257x_MAX_DESC - 1
	mov [i8257x_tx_lasttail], eax
	mov rdi, [os_NetIOBaseMem]
	mov [rdi+i8257x_TDT], eax	; TDL - Transmit Descriptor Tail

	pop rax
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8257x_poll - Polls the Intel 8257x NIC for a received packet
;  IN:	RDI = Location to store packet
; OUT:	RCX = Length of packet
; Note:	RDESC Descriptor Format:
;	First Qword:
;	Bits 63:0 - Buffer Address
;	Second Qword:
;	Bits 15:0 - Length
;	Bits 31:16 - Fragment Checksum
;	Bits 39:32 - STA - Status
;	Bits 47:40 - Errors
;	Bits 63:48 - VLAN
net_i8257x_poll:
	push rdi
	push rsi			; Used for the base MMIO of the NIC
	push rax

	mov rdi, os_rx_desc
	mov rsi, [os_NetIOBaseMem]	; Load the base MMIO of the NIC

	; Calculate the descriptor to read from
	mov eax, [i8257x_rx_lasthead]
	shl eax, 4			; Quick multiply by 16
	add eax, 8			; Offset to bytes received
	add rdi, rax			; Add offset to RDI
	; Todo: read all 64 bits. check status bit for DD
	xor ecx, ecx			; Clear RCX
	mov cx, [rdi]			; Get the packet length
	cmp cx, 0
	je net_i8257x_poll_end		; No data? Bail out

	xor eax, eax
	stosq				; Clear the descriptor length and status

	; Increment i8257x_rx_lasthead and the Receive Descriptor Tail
	mov eax, [i8257x_rx_lasthead]
	add eax, 1
	and eax, i8257x_MAX_DESC - 1
	mov [i8257x_rx_lasthead], eax
	mov eax, [rsi+i8257x_RDT]	; Read the current Receive Descriptor Tail
	add eax, 1			; Add 1 to the Receive Descriptor Tail
	and eax, i8257x_MAX_DESC - 1
	mov [rsi+i8257x_RDT], eax	; Write the updated Receive Descriptor Tail

	pop rax
	pop rsi
	pop rdi
	ret

net_i8257x_poll_end:
	xor ecx, ecx
	pop rax
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; Variables
i8257x_tx_lasttail: dd 0
i8257x_rx_lasthead: dd 0

; Constants
i8257x_MAX_PKT_SIZE	equ 16384
i8257x_MAX_DESC		equ 16		; Must be 16, 32, 64, 128, etc.

; Register list (13.3) (All registers should be accessed as 32-bit values)

; General Control Registers
i8257x_CTRL		equ 0x00000 ; Device Control Register
i8257x_CTRL_Legacy	equ 0x00004 ; Copy of Device Control Register
i8257x_STATUS		equ 0x00008 ; Device Status Register
i8257x_CTRL_EXT		equ 0x00018 ; Extended Device Control Register
i8257x_MDIC		equ 0x00020 ; MDI Control Register
i8257x_LEDCTL		equ 0x00E00 ; LED Control

; EEPROM / Flash Registers

; Interrupts Registers
i8257x_ICR		equ 0x000C0 ; Interrupt Cause Read
i8257x_ITR		equ 0x000C4 ; Interrupt Throttling Rate
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
i8257x_RDTR		equ 0x02820 ; Receive Interrupt Packet Delay Timer
i8257x_RXDCTL		equ 0x02828 ; Receive Descriptor Control Queue 0
i8257x_RADV		equ 0x0282C ; Receive Interrupt Absolute Delay Timer
i8257x_RSRPD		equ 0x02C00 ; Receive Small Packet Detect
i8257x_RXCSUM		equ 0x05000 ; Receive Checksum Control
i8257x_RLPML		equ 0x05004 ; Receive Long packet maximal length
i8257x_RFCTL		equ 0x05008 ; Receive Filter Control Register
i8257x_MTA		equ 0x05200 ; Multicast Table Array (n)
i8257x_RAL		equ 0x05400 ; Receive Address Low (Lower 32-bits of 48-bit address)
i8257x_RAH		equ 0x05404 ; Receive Address High (Upper 16-bits of 48-bit address). Bit 31 should be set for Address Valid

; Transmit Registers
i8257x_TCTL		equ 0x00400 ; Transmit Control
i8257x_TIPG		equ 0x00410 ; Transmit IPG (Inter Packet Gap)
i8257x_TDBAL		equ 0x03800 ; Transmit Descriptor Base Address Low
i8257x_TDBAH		equ 0x03804 ; Transmit Descriptor Base Address High
i8257x_TDLEN		equ 0x03808 ; Transmit Descriptor Length (Bits 19:0 in bytes, 128-byte aligned)
i8257x_TDH		equ 0x03810 ; Transmit Descriptor Head (Bits 15:0)
i8257x_TDT		equ 0x03818 ; Transmit Descriptor Tail (Bits 15:0)
i8257x_TIDV		equ 0x03820 ; Transmit Interrupt Delay Value
i8257x_TXDCTL		equ 0x03828 ; Transmit Descriptor Control (Bit 25 - Enable)
i8257x_TADV		equ 0x0382C ; Transmit Absolute Interrupt Delay Value
i8257x_TARC0		equ 0x03840 ; Transmit Arbitration Counter Queue 0

; Statistic Registers
i8257x_GPRC		equ 0x04074 ; Good Packets Received Count
i8257x_BPRC		equ 0x04078 ; Broadcast Packets Received Count
i8257x_MPRC		equ 0x0407C ; Multicast Packets Received Count
i8257x_GPTC		equ 0x04080 ; Good Packets Transmitted Count
i8257x_GORCL		equ 0x04088 ; Good Octets Received Count Low
i8257x_GORCH		equ 0x0408C ; Good Octets Received Count High
i8257x_GOTCL		equ 0x04090 ; Good Octets Transmitted Count Low
i8257x_GOTCH		equ 0x04094 ; Good Octets Transmitted Count High

; Register bits

; CTRL (Device Control Register, 0x00000 / 0x00004, RW) Bit Masks
i8257x_CTRL_FD		equ 0 ; Full-Duplex
i8257x_CTRL_GIO		equ 2 ; GIO Master Disable
i8257x_CTRL_LRST	equ 3 ; Link Reset
i8257x_CTRL_SLU		equ 6 ; Set Link Up
i8257x_CTRL_SPEED	equ 8 ; 2 bits - Speed selection
i8257x_CTRL_FRCSPD	equ 11 ; Force Speed
i8257x_CTRL_FRCDPLX	equ 12 ; Force Duplex
i8257x_CTRL_RST		equ 26 ; Device Reset
i8257x_CTRL_RFCE	equ 27 ; Receive Flow Control Enable
i8257x_CTRL_TFCE	equ 28 ; Transmit Flow Control Enable
i8257x_CTRL_VME		equ 30 ; VLAN Mode Enable
i8257x_CTRL_PHY_RST	equ 31 ; PHY Reset
; All other bits are reserved and should be written as 0
i8257x_CTRL_RST_MASK	equ 1 << i8257x_CTRL_LRST | 1 << i8257x_CTRL_RST

; STATUS (Device Status Register, 0x00008, R)
i8257x_STATUS_FD	equ 0 ; Link Full Duplex configuration Indication
i8257x_STATUS_LU	equ 1 ; Link Up Indication
i8257x_STATUS_LANID	equ 2 ; 2 bits - LAN ID
i8257x_STATUS_TXOFF	equ 4 ; Transmission Paused
i8257x_STATUS_TBIMODE	equ 5 ; TBI Mode
i8257x_STATUS_SPEED	equ 6 ; 2 bits - Link speed setting
i8257x_STATUS_ASDV	equ 8 ; 2 bits - Auto Speed Detection Value
i8257x_STATUS_PHYRA	equ 10 ; PHY Reset Asserted
i8257x_STATUS_GIO	equ 19 ; GIO Master Enable Status

; CTRL_EXT (Extended Device Control Register, 0x00018, RW) Bit Masks
i8257x_CTRL_EXT_ASDCHK	equ 12 ; ASD Check
i8257x_CTRL_EXT_DRV_LOAD	equ 28 ; Driver loaded and the corresponding network interface is enabled

; RCTL (Receive Control Register, 0x00100, RW) Bit Masks
i8257x_RCTL_EN		equ 1 ; Receive Enable
i8257x_RCTL_SBP		equ 2 ; Store Bad Packets
i8257x_RCTL_UPE		equ 3 ; Unicast Promiscuous Enabled
i8257x_RCTL_MPE		equ 4 ; Multicast Promiscuous Enabled
i8257x_RCTL_LPE		equ 5 ; Long Packet Reception Enable
i8257x_RCTL_BAM		equ 15 ; Broadcast Accept Mode
i8257x_RCTL_SECRC	equ 26 ; Strip Ethernet CRC from incoming packet

; TCTL (Transmit Control Register, 0x00400, RW) Bit Masks
i8257x_TCTL_EN		equ 1 ; Transmit Enable
i8257x_TCTL_PSP		equ 3 ; Pad Short Packets
i8257x_TCTL_CT		equ 4 ; Collision Threshold (11:4)
i8257x_TCTL_COLD	equ 12 ; Collision Distance (21:12)
i8257x_TCTL_RRTHRESH	equ 29 ; Read Request Threshold (30:29)

; All other bits are reserved and should be written as 0

i8257x_IRQ_CLEAR_MASK	equ 0xFFFFFFFF

; =============================================================================
; EOF
