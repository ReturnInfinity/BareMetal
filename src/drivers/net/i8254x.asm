; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Intel 8254x Gigabit Ethernet Driver
; =============================================================================


; -----------------------------------------------------------------------------
; Initialize an Intel 8254x NIC
;  IN:	RDX = Packed Bus address (as per syscalls/bus.asm)
net_i8254x_init:
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
	mov eax, [rsi+i8254x_RAL]	; RAL
	mov [os_NetMAC], al
	shr eax, 8
	mov [os_NetMAC+1], al
	shr eax, 8
	mov [os_NetMAC+2], al
	shr eax, 8
	mov [os_NetMAC+3], al
	mov eax, [rsi+i8254x_RAH]	; RAH
	mov [os_NetMAC+4], al
	shr eax, 8
	mov [os_NetMAC+5], al

	; Reset the device
	call net_i8254x_reset

net_i8254x_init_error:

	pop rax
	pop rcx
	pop rdx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8254x_reset - Reset an Intel 8254x NIC
;  IN:	Nothing
; OUT:	Nothing, all registers preserved
net_i8254x_reset:
	push rdi
	push rsi
	push rax

	mov rsi, [os_NetIOBaseMem]
	mov rdi, rsi

	; Disable Interrupts
	mov eax, i8254x_IRQ_CLEAR_MASK
	mov [rsi+i8254x_IMC], eax	; Disable all interrupt causes
	xor eax, eax
	mov [rsi+i8254x_ITR], eax	; Disable interrupt throttling logic
	mov [rsi+i8254x_IMS], eax	; Mask all interrupts
	mov eax, [rsi+i8254x_ICR]	; Clear any pending interrupts

; TODO - Needed?
;	mov eax, 0x00000030
;	mov [rsi+i8254x_PBA], eax	; PBA: set the RX buffer size to 48KB (TX buffer is calculated as 64-RX buffer)
;	mov eax, 0x80008060
;	mov [rsi+i8254x_TXCW], eax	; TXCW: set ANE, TxConfigWord (Half/Full duplex, Next Page Request)

	mov eax, [rsi+i8254x_CTRL]
	; Clear the bits we don't want
	and eax, 0xFFFFFFFF - (1 << i8254x_CTRL_LRST | 1 << i8254x_CTRL_VME)
	; Set the bits we do want
	or eax, 1 << i8254x_CTRL_FD | 1 << i8254x_CTRL_SLU | 1 << i8254x_CTRL_ASDE
	mov [rsi+i8254x_CTRL], eax

	; Initialize all statistical counters ()
	mov eax, [rsi+i8254x_GPRC]	; RX packets
	mov eax, [rsi+i8254x_GPTC]	; TX packets
	mov eax, [rsi+i8254x_GORCL]
	mov eax, [rsi+i8254x_GORCH]	; RX bytes = GORCL + (GORCH << 32)
	mov eax, [rsi+i8254x_GOTCL]
	mov eax, [rsi+i8254x_GOTCH]	; TX bytes = GOTCL + (GOTCH << 32)

	push rdi
	add rdi, i8254x_MTA		; MTA: reset
	mov eax, 0xFFFFFFFF
	stosd
	stosd
	stosd
	stosd
	pop rdi

	; Create RX descriptors
	push rdi
	mov ecx, i8254x_MAX_DESC
	mov rdi, os_rx_desc
net_i8254x_reset_nextdesc:	
	mov rax, os_PacketBuffers	; Default packet will go here
	stosq
	xor eax, eax
	stosq
	dec ecx
	jnz net_i8254x_reset_nextdesc
	pop rdi

	; Initialize receive
	mov rax, os_rx_desc
	mov [rsi+i8254x_RDBAL], eax	; Receive Descriptor Base Address Low
	shr rax, 32
	mov [rsi+i8254x_RDBAH], eax	; Receive Descriptor Base Address High
	mov eax, i8254x_MAX_DESC * 16	; Each descriptor is 16 bytes
	mov [rsi+i8254x_RDLEN], eax	; Receive Descriptor Length
	xor eax, eax			; 0 is the first valid descriptor
	mov [rsi+i8254x_RDH], eax	; Receive Descriptor Head
	mov eax, i8254x_MAX_DESC / 2
	mov [rsi+i8254x_RDT], eax	; Receive Descriptor Tail
	mov eax, 1 << i8254x_RCTL_EN | 1 << i8254x_RCTL_UPE | 1 << i8254x_RCTL_MPE | 1 << i8254x_RCTL_LPE | 1 << i8254x_RCTL_BAM | 1 << i8254x_RCTL_SECRC
	mov [rsi+i8254x_RCTL], eax	; Receive Control Register

	; Initialize transmit
	mov rax, os_tx_desc
	mov [rsi+i8254x_TDBAL], eax	; Transmit Descriptor Base Address Low
	shr rax, 32
	mov [rsi+i8254x_TDBAH], eax	; Transmit Descriptor Base Address High
	mov eax, i8254x_MAX_DESC * 16	; Each descriptor is 16 bytes
	mov [rsi+i8254x_TDLEN], eax	; Transmit Descriptor Length
	xor eax, eax
	mov [rsi+i8254x_TDH], eax	; Transmit Descriptor Head
	mov [rsi+i8254x_TDT], eax	; Transmit Descriptor Tail
	mov eax, 1 << i8254x_TCTL_EN | 1 << i8254x_TCTL_PSP | 15 << i8254x_TCTL_CT | 0x40 << i8254x_TCTL_COLD | 1 << i8254x_TCTL_RTLC
	mov [rsi+i8254x_TCTL], eax	; Transmit Control Register
	mov eax, 0x0060200A		; IPGT 10 (9:0), IPGR1 8 (19:10), IPGR2 6 (29:20)
	mov [rsi+i8254x_TIPG], eax	; Transmit IPG Register

	xor eax, eax
	mov [rsi+i8254x_RDTR], eax	; Clear the Receive Delay Timer Register
	mov [rsi+i8254x_RADV], eax	; Clear the Receive Interrupt Absolute Delay Timer
	mov [rsi+i8254x_RSRPD], eax	; Clear the Receive Small Packet Detect Interrupt

	pop rax
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8254x_transmit - Transmit a packet via an Intel 8254x NIC
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
;	Bits 39:36 - Reserved
;	Bits 47:40 - CSS - Checksum Start
;	Bits 63:48 - Special
net_i8254x_transmit:
	push rdi
	push rax

	mov rdi, os_tx_desc		; Transmit Descriptor Base Address

	; Calculate the descriptor to write to
	mov eax, [i8254x_tx_lasttail]
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

	; Increment i8254x_tx_lasttail and the Transmit Descriptor Tail
	pop rax				; Restore lasttail
	add eax, 1
	and eax, i8254x_MAX_DESC - 1
	mov [i8254x_tx_lasttail], eax
	mov rdi, [os_NetIOBaseMem]
	mov [rdi+i8254x_TDT], eax	; TDL - Transmit Descriptor Tail

	pop rax
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8254x_poll - Polls the Intel 8254x NIC for a received packet
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
;	Bits 63:48 - Special
net_i8254x_poll:
	push rdi
	push rsi			; Used for the base MMIO of the NIC
	push rax

	mov rdi, os_rx_desc
	mov rsi, [os_NetIOBaseMem]	; Load the base MMIO of the NIC

	; Calculate the descriptor to read from
	mov eax, [i8254x_rx_lasthead]
	shl eax, 4			; Quick multiply by 16
	add eax, 8			; Offset to bytes received
	add rdi, rax			; Add offset to RDI
	; Todo: read all 64 bits. check status bit for DD
	xor ecx, ecx			; Clear RCX
	mov cx, [rdi]			; Get the packet length
	cmp cx, 0
	je net_i8254x_poll_end		; No data? Bail out

	xor eax, eax
	stosq				; Clear the descriptor length and status

	; Increment i8254x_rx_lasthead and the Receive Descriptor Tail
	mov eax, [i8254x_rx_lasthead]
	add eax, 1
	and eax, i8254x_MAX_DESC - 1
	mov [i8254x_rx_lasthead], eax
	mov eax, [rsi+i8254x_RDT]	; Read the current Receive Descriptor Tail
	add eax, 1			; Add 1 to the Receive Descriptor Tail
	and eax, i8254x_MAX_DESC - 1
	mov [rsi+i8254x_RDT], eax	; Write the updated Receive Descriptor Tail

	pop rax
	pop rsi
	pop rdi
	ret

net_i8254x_poll_end:
	xor ecx, ecx
	pop rax
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8254x_ack_int - Acknowledge an internal interrupt of the Intel 8254x NIC
;  IN:	Nothing
; OUT:	RAX = Ethernet status
;net_i8254x_ack_int:
;	push rdi
;
;	xor eax, eax
;	mov rdi, [os_NetIOBaseMem]
;	mov eax, [rdi+i8254x_ICR]
;
;	pop rdi
;	ret
; -----------------------------------------------------------------------------


; Variables
i8254x_tx_lasttail: dd 0
i8254x_rx_lasthead: dd 0

; Constants
i8254x_MAX_PKT_SIZE	equ 16384
i8254x_MAX_DESC		equ 16		; Must be 16, 32, 64, 128, etc.

; Register list (13.2) (All registers should be accessed as 32-bit values)

; General Control Registers
i8254x_CTRL		equ 0x0000 ; Control Register
i8254x_STATUS		equ 0x0008 ; Device Status Register
i8254x_CTRLEXT		equ 0x0018 ; Extended Control Register
i8254x_MDIC		equ 0x0020 ; MDI Control Register
i8254x_FCAL		equ 0x0028 ; Flow Control Address Low
i8254x_FCAH		equ 0x002C ; Flow Control Address High
i8254x_FCT		equ 0x0030 ; Flow Control Type
i8254x_VET		equ 0x0038 ; VLAN Ether Type
i8254x_FCTTV		equ 0x0170 ; Flow Control Transmit Timer Value
i8254x_TXCW		equ 0x0178 ; Transmit Configuration Word
i8254x_RXCW		equ 0x0180 ; Receive Configuration Word
i8254x_LEDCTL		equ 0x0E00 ; LED Control
i8254x_PBA		equ 0x1000 ; Packet Buffer Allocation

; Interrupts Registers
i8254x_ICR		equ 0x00C0 ; Interrupt Cause Read
i8254x_ITR		equ 0x00C4 ; Interrupt Throttling Register
i8254x_ICS		equ 0x00C8 ; Interrupt Cause Set Register
i8254x_IMS		equ 0x00D0 ; Interrupt Mask Set/Read Register
i8254x_IMC		equ 0x00D8 ; Interrupt Mask Clear Register

; Receive Registers
i8254x_RCTL		equ 0x0100 ; Receive Control Register
i8254x_RDBAL		equ 0x2800 ; RX Descriptor Base Address Low
i8254x_RDBAH		equ 0x2804 ; RX Descriptor Base Address High
i8254x_RDLEN		equ 0x2808 ; RX Descriptor Length (128-byte aligned)
i8254x_RDH		equ 0x2810 ; RX Descriptor Head
i8254x_RDT		equ 0x2818 ; RX Descriptor Tail
i8254x_RDTR		equ 0x2820 ; RX Delay Timer Register
i8254x_RXDCTL		equ 0x3828 ; RX Descriptor Control
i8254x_RADV		equ 0x282C ; RX Int. Absolute Delay Timer
i8254x_RSRPD		equ 0x2C00 ; RX Small Packet Detect Interrupt
i8254x_RXCSUM		equ 0x5000 ; RX Checksum Control
i8254x_MTA		equ 0x5200 ; Multicast Table Array
i8254x_RAL		equ 0x5400 ; Receive Address Low (Lower 32-bits of 48-bit address)
i8254x_RAH		equ 0x5404 ; Receive Address High (Upper 16-bits of 48-bit address). Bit 31 should be set for Address Valid

; Transmit Registers
i8254x_TCTL		equ 0x0400 ; Transmit Control Register
i8254x_TIPG		equ 0x0410 ; Transmit Inter Packet Gap
i8254x_TXDMAC		equ 0x3000 ; TX DMA Control
i8254x_TDBAL		equ 0x3800 ; TX Descriptor Base Address Low
i8254x_TDBAH		equ 0x3804 ; TX Descriptor Base Address High
i8254x_TDLEN		equ 0x3808 ; TX Descriptor Length
i8254x_TDH		equ 0x3810 ; TX Descriptor Head
i8254x_TDT		equ 0x3818 ; TX Descriptor Tail
i8254x_TIDV		equ 0x3820 ; TX Interrupt Delay Value
i8254x_TXDCTL		equ 0x3828 ; TX Descriptor Control
i8254x_TADV		equ 0x382C ; TX Absolute Interrupt Delay Value
i8254x_TSPMT		equ 0x3830 ; TCP Segmentation Pad & Min Threshold

; Statistic Registers
i8254x_GPRC		equ 0x04074 ; Good Packets Received Count
i8254x_BPRC		equ 0x04078 ; Broadcast Packets Received Count
i8254x_MPRC		equ 0x0407C ; Multicast Packets Received Count
i8254x_GPTC		equ 0x04080 ; Good Packets Transmitted Count
i8254x_GORCL		equ 0x04088 ; Good Octets Received Count Low
i8254x_GORCH		equ 0x0408C ; Good Octets Received Count High
i8254x_GOTCL		equ 0x04090 ; Good Octets Transmitted Count Low
i8254x_GOTCH		equ 0x04094 ; Good Octets Transmitted Count High

; Register bits

; CTRL (Device Control Register, 0x00000 / 0x00004, RW) Bit Masks
i8254x_CTRL_FD		equ 0 ; Full-Duplex
i8254x_CTRL_LRST	equ 3 ; Link Reset
i8254x_CTRL_ASDE	equ 5 ; Auto-Speed Detection Enable
i8254x_CTRL_SLU		equ 6 ; Set Link Up
i8254x_CTRL_SPEED	equ 8 ; 2 bits - Speed selection
i8254x_CTRL_FRCSPD	equ 11 ; Force Speed
i8254x_CTRL_FRCDPLX	equ 12 ; Force Duplex
i8254x_CTRL_RST		equ 26 ; Device Reset
i8254x_CTRL_RFCE	equ 27 ; Receive Flow Control Enable
i8254x_CTRL_TFCE	equ 28 ; Transmit Flow Control Enable
i8254x_CTRL_VME		equ 30 ; VLAN Mode Enable
i8254x_CTRL_PHY_RST	equ 31 ; PHY Reset

i8254x_CTRL_RST_MASK	equ 1 << i8254x_CTRL_LRST | 1 << i8254x_CTRL_RST

; STATUS - Device Status Register (0x0008)
i8254x_STATUS_FD		equ 0x00000001 ; Full Duplex
i8254x_STATUS_LU		equ 0x00000002 ; Link Up
i8254x_STATUS_TXOFF		equ 0x00000010 ; Transmit paused
i8254x_STATUS_TBIMODE		equ 0x00000020 ; TBI Mode
i8254x_STATUS_SPEED_MASK	equ 0x000000C0 ; Link Speed setting
i8254x_STATUS_SPEED_SHIFT	equ 6
i8254x_STATUS_ASDV_MASK		equ 0x00000300 ; Auto Speed Detection
i8254x_STATUS_ASDV_SHIFT	equ 8
i8254x_STATUS_PCI66		equ 0x00000800 ; PCI bus speed
i8254x_STATUS_BUS64		equ 0x00001000 ; PCI bus width
i8254x_STATUS_PCIX_MODE		equ 0x00002000 ; PCI-X mode
i8254x_STATUS_PCIXSPD_MASK	equ 0x0000C000 ; PCI-X speed
i8254x_STATUS_PCIXSPD_SHIFT	equ 14

; CTRL_EXT - Extended Device Control Register (0x0018)
i8254x_CTRLEXT_PHY_INT		equ 0x00000020 ; PHY interrupt
i8254x_CTRLEXT_SDP6_DATA	equ 0x00000040 ; SDP6 data
i8254x_CTRLEXT_SDP7_DATA	equ 0x00000080 ; SDP7 data
i8254x_CTRLEXT_SDP6_IODIR	equ 0x00000400 ; SDP6 direction
i8254x_CTRLEXT_SDP7_IODIR	equ 0x00000800 ; SDP7 direction
i8254x_CTRLEXT_ASDCHK		equ 0x00001000 ; Auto-Speed Detect Chk
i8254x_CTRLEXT_EE_RST		equ 0x00002000 ; EEPROM reset
i8254x_CTRLEXT_SPD_BYPS		equ 0x00008000 ; Speed Select Bypass
i8254x_CTRLEXT_RO_DIS		equ 0x00020000 ; Relaxed Ordering Dis.
i8254x_CTRLEXT_LNKMOD_MASK	equ 0x00C00000 ; Link Mode
i8254x_CTRLEXT_LNKMOD_SHIFT	equ 22

; MDIC - MDI Control Register (0x0020)
i8254x_MDIC_DATA_MASK	equ 0x0000FFFF ; Data
i8254x_MDIC_REG_MASK	equ 0x001F0000 ; PHY Register
i8254x_MDIC_REG_SHIFT	equ 16
i8254x_MDIC_PHY_MASK	equ 0x03E00000 ; PHY Address
i8254x_MDIC_PHY_SHIFT	equ 21
i8254x_MDIC_OP_MASK	equ 0x0C000000 ; Opcode
i8254x_MDIC_OP_SHIFT	equ 26
i8254x_MDIC_R		equ 0x10000000 ; Ready
i8254x_MDIC_I		equ 0x20000000 ; Interrupt Enable
i8254x_MDIC_E		equ 0x40000000 ; Error

; ICR - Interrupt Cause Read (0x00c0)
i8254x_ICR_TXDW		equ 0x00000001 ; TX Desc Written back
i8254x_ICR_TXQE		equ 0x00000002 ; TX Queue Empty
i8254x_ICR_LSC		equ 0x00000004 ; Link Status Change
i8254x_ICR_RXSEQ	equ 0x00000008 ; RX Sequence Error
i8254x_ICR_RXDMT0	equ 0x00000010 ; RX Desc min threshold reached
i8254x_ICR_RXO		equ 0x00000040 ; RX Overrun
i8254x_ICR_RXT0		equ 0x00000080 ; RX Timer Interrupt
i8254x_ICR_MDAC		equ 0x00000200 ; MDIO Access Complete
i8254x_ICR_RXCFG	equ 0x00000400
i8254x_ICR_PHY_INT	equ 0x00001000 ; PHY Interrupt
i8254x_ICR_GPI_SDP6	equ 0x00002000 ; GPI on SDP6
i8254x_ICR_GPI_SDP7	equ 0x00004000 ; GPI on SDP7
i8254x_ICR_TXD_LOW	equ 0x00008000 ; TX Desc low threshold hit
i8254x_ICR_SRPD		equ 0x00010000 ; Small RX packet detected

; RCTL (Receive Control Register, 0x00100, RW) Bit Masks
i8254x_RCTL_EN		equ 1 ; Receiver Enable
i8254x_RCTL_SBP		equ 2 ; Store Bad Packets
i8254x_RCTL_UPE		equ 3 ; Unicast Promiscuous Enabled
i8254x_RCTL_MPE		equ 4 ; Xcast Promiscuous Enabled
i8254x_RCTL_LPE		equ 5 ; Long Packet Reception Enable
i8254x_RCTL_LBM		equ 6 ; 2 bits - Loopback Mode
i8254x_RCTL_RDMTS	equ 8 ; 2 bits - RX Desc Min Threshold Size
i8254x_RCTL_MO		equ 12 ; 2 bits - Multicast Offset
i8254x_RCTL_BAM		equ 15 ; Broadcast Accept Mode
i8254x_RCTL_BSIZE	equ 16 ;  2 bits - RX Buffer Size
i8254x_RCTL_VFE		equ 18 ; VLAN Filter Enable
i8254x_RCTL_CFIEN	equ 19 ; CFI Enable
i8254x_RCTL_CFI		equ 20 ; Canonical Form Indicator Bit
i8254x_RCTL_DPF		equ 22 ; Discard Pause Frames
i8254x_RCTL_PMCF	equ 23 ; Pass MAC Control Frames
i8254x_RCTL_BSEX	equ 25 ; Buffer Size Extension
i8254x_RCTL_SECRC	equ 26 ; Strip Ethernet CRC

; TCTL (Transmit Control Register, 0x00400, RW) Bit Masks
i8254x_TCTL_EN		equ 1 ; Transmit Enable
i8254x_TCTL_PSP		equ 3 ; Pad Short Packets
i8254x_TCTL_CT		equ 4 ; Collision Threshold (11:4)
i8254x_TCTL_COLD	equ 12 ; Collision Distance (21:12)
i8254x_TCTL_RTLC	equ 24 ; Re-transmit on Late Collision


; PBA - Packet Buffer Allocation (0x1000)
i8254x_PBA_RXA_MASK	equ 0x0000FFFF ; RX Packet Buffer
i8254x_PBA_RXA_SHIFT	equ 0
i8254x_PBA_TXA_MASK	equ 0xFFFF0000 ; TX Packet Buffer
i8254x_PBA_TXA_SHIFT	equ 16

; Flow Control Type
i8254x_FCT_TYPE_DEFAULT	equ 0x8808

; === TX Descriptor fields ===

; TX Packet Length (word 2)
i8254x_TXDESC_LEN_MASK	equ 0x0000ffff

; TX Descriptor CMD field (word 2)
i8254x_TXDESC_IDE	equ 0x80000000 ; Interrupt Delay Enable
i8254x_TXDESC_VLE	equ 0x40000000 ; VLAN Packet Enable
i8254x_TXDESC_DEXT	equ 0x20000000 ; Extension
i8254x_TXDESC_RPS	equ 0x10000000 ; Report Packet Sent
i8254x_TXDESC_RS	equ 0x08000000 ; Report Status
i8254x_TXDESC_IC	equ 0x04000000 ; Insert Checksum
i8254x_TXDESC_IFCS	equ 0x02000000 ; Insert FCS
i8254x_TXDESC_EOP	equ 0x01000000 ; End Of Packet

; TX Descriptor STA field (word 3)
i8254x_TXDESC_TU	equ 0x00000008 ; Transmit Underrun
i8254x_TXDESC_LC	equ 0x00000004 ; Late Collision
i8254x_TXDESC_EC	equ 0x00000002 ; Excess Collisions
i8254x_TXDESC_DD	equ 0x00000001 ; Descriptor Done

; === RX Descriptor fields ===

; RX Packet Length (word 2)
i8254x_RXDESC_LEN_MASK	equ 0x0000ffff

; RX Descriptor STA field (word 3)
i8254x_RXDESC_PIF	equ 0x00000080 ; Passed In-exact Filter
i8254x_RXDESC_IPCS	equ 0x00000040 ; IP cksum calculated
i8254x_RXDESC_TCPCS	equ 0x00000020 ; TCP cksum calculated
i8254x_RXDESC_VP	equ 0x00000008 ; Packet is 802.1Q
i8254x_RXDESC_IXSM	equ 0x00000004 ; Ignore cksum indication
i8254x_RXDESC_EOP	equ 0x00000002 ; End Of Packet
i8254x_RXDESC_DD	equ 0x00000001 ; Descriptor Done


i8254x_IRQ_CLEAR_MASK	equ 0xFFFFFFFF

; =============================================================================
; EOF
