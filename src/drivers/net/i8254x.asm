; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; Intel i8254x Driver
; =============================================================================


; -----------------------------------------------------------------------------
; Initialize an Intel 8254x NIC
;  IN:	RDX = Packed Bus address (as per syscalls/bus.asm)
net_i8254x_init:
	push rsi
	push rdx
	push rcx
	push rax

	; Read BAR4, If BAR4 is all zeros then we are using 32-bit addresses

	; Grab the Base I/O Address of the device
	mov dl, 0x04				; BAR0
	call os_bus_read
	and eax, 0xFFFFFFF0			; EAX now holds the Base Memory IO Address (clear the low 4 bits)
	mov dword [os_NetIOBaseMem], eax

	; Grab the IRQ of the device
	mov dl, 0x0F				; Get device's IRQ number from Bus Register 15 (IRQ is bits 7-0)
	call os_bus_read
	mov [os_NetIRQ], al			; AL holds the IRQ

	; Enable PCI Bus Mastering
	mov dl, 0x01				; Get Status/Command
	call os_bus_read
	bts eax, 2
	call os_bus_write

	; Grab the MAC address
	mov rsi, [os_NetIOBaseMem]
	mov eax, [rsi+0x5400]			; RAL
	cmp eax, 0x00000000
	je net_i8254x_init_get_MAC_via_EPROM
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
	jmp net_i8254x_init_done_MAC

net_i8254x_init_get_MAC_via_EPROM:
	mov rsi, [os_NetIOBaseMem]
	mov eax, 0x00000001
	mov [rsi+0x14], eax
	mov eax, [rsi+0x14]
	shr eax, 16
	mov [os_NetMAC], al
	shr eax, 8
	mov [os_NetMAC+1], al
	mov eax, 0x00000101
	mov [rsi+0x14], eax
	mov eax, [rsi+0x14]
	shr eax, 16
	mov [os_NetMAC+2], al
	shr eax, 8
	mov [os_NetMAC+3], al
	mov eax, 0x00000201
	mov [rsi+0x14], eax
	mov eax, [rsi+0x14]
	shr eax, 16
	mov [os_NetMAC+4], al
	shr eax, 8
	mov [os_NetMAC+5], al
net_i8254x_init_done_MAC:

	; Reset the device
	call net_i8254x_reset

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

	mov eax, 0xFFFFFFFF
	mov [rsi+I8254X_REG_IMC], eax		; Disable all interrupt causes
	mov eax, [rsi+I8254X_REG_ICR]		; Clear any pending interrupts
	xor eax, eax
	mov [rsi+I8254X_REG_ITR], eax		; Disable interrupt throttling logic

	mov eax, 0x00000030
	mov [rsi+I8254X_REG_PBA], eax		; PBA: set the RX buffer size to 48KB (TX buffer is calculated as 64-RX buffer)

	mov eax, 0x80008060
	mov [rsi+I8254X_REG_TXCW], eax		; TXCW: set ANE, TxConfigWord (Half/Full duplex, Next Page Request)

	mov eax, [rsi+I8254X_REG_CTRL]
	btr eax, 3				; LRST = 0
	bts eax, 6				; SLU = 1
	bts eax, 5				; ASDE = 1
	btr eax, 31				; PHY_RST = 0
	btr eax, 30				; VME = 0 (Disable 802.1Q)
	btr eax, 7				; ILOS = 0
	mov [rsi+I8254X_REG_CTRL], eax		; CTRL: clear LRST, set SLU and ASDE, clear RSTPHY, VME, and ILOS

	push rdi
	add rdi, I8254X_REG_MTA			; MTA: reset
	mov eax, 0xFFFFFFFF
	stosd
	stosd
	stosd
	stosd
	pop rdi

	mov rax, os_rx_desc
	mov [rsi+I8254X_REG_RDBAL], eax		; Receive Descriptor Base Address Low
	shr rax, 32
	mov [rsi+I8254X_REG_RDBAH], eax		; Receive Descriptor Base Address High
	mov eax, (32 * 8)			; Multiples of 8, each descriptor is 16 bytes
	mov [rsi+I8254X_REG_RDLEN], eax		; Receive Descriptor Length
	xor eax, eax
	mov [rsi+I8254X_REG_RDH], eax		; Receive Descriptor Head
	mov eax, 1
	mov [rsi+I8254X_REG_RDT], eax		; Receive Descriptor Tail
	mov eax, 0x04008026			; Receiver Enable, Store Bad Packets, Long Packet Reception, Broadcast Accept Mode, Strip Ethernet CRC from incoming packet
	mov [rsi+I8254X_REG_RCTL], eax		; Receive Control Register

	push rdi
	mov rdi, os_rx_desc
	mov rax, os_PacketBuffers		; Default packet will go here
	add rax, 2				; Room for packet length
	stosd
	pop rdi

	mov rax, os_tx_desc
	mov [rsi+I8254X_REG_TDBAL], eax		; Transmit Descriptor Base Address Low
	shr rax, 32
	mov [rsi+I8254X_REG_TDBAH], eax		; Transmit Descriptor Base Address High
	mov eax, (32 * 8)			; Multiples of 8, each descriptor is 16 bytes
	mov [rsi+I8254X_REG_TDLEN], eax		; Transmit Descriptor Length
	xor eax, eax
	mov [rsi+I8254X_REG_TDH], eax		; Transmit Descriptor Head
	mov [rsi+I8254X_REG_TDT], eax		; Transmit Descriptor Tail
	mov eax, 0x010400FA			; Enabled, Pad Short Packets, 15 retries, 64-byte COLD, Re-transmit on Late Collision
	mov [rsi+I8254X_REG_TCTL], eax		; Transmit Control Register
	mov eax, 0x0060200A			; IPGT 10, IPGR1 8, IPGR2 6
	mov [rsi+I8254X_REG_TIPG], eax		; Transmit IPG Register

	xor eax, eax
	mov [rsi+I8254X_REG_RDTR], eax		; Clear the Receive Delay Timer Register
	mov [rsi+I8254X_REG_RADV], eax		; Clear the Receive Interrupt Absolute Delay Timer
	mov [rsi+I8254X_REG_RSRPD], eax		; Clear the Receive Small Packet Detect Interrupt

	mov eax, 0x1FFFF			; Temp enable all interrupt types
	mov [rsi+I8254X_REG_IMS], eax		; Enable interrupt types

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
; Note:	This driver uses the "legacy format" so TDESC.DEXT is set to 0
;	Descriptor Format:
;	Bytes 7:0 - Buffer Address
;	Bytes 9:8 - Length
;	Bytes 13:10 - Flags
;	Bytes 15:14 - Special
net_i8254x_transmit:
	push rdi
	push rax

	mov rdi, os_tx_desc			; Transmit Descriptor Base Address
	mov rax, rsi
	stosq					; Store the data location
	mov rax, rcx				; The packet size is in CX
	bts rax, 24				; TDESC.CMD.EOP - End Of Packet
	bts rax, 25				; TDESC.CMD.IFCS - Insert FCS
	bts rax, 27				; TDESC.CMD.RS - Report Status
	stosq
	mov rdi, [os_NetIOBaseMem]
	xor eax, eax
	mov [rdi+I8254X_REG_TDH], eax		; TDH - Transmit Descriptor Head
	inc eax
	mov [rdi+I8254X_REG_TDT], eax		; TDL - Transmit Descriptor Tail

	pop rax
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8254x_poll - Polls the Intel 8254x NIC for a received packet
;  IN:	RDI = Location to store packet
; OUT:	RCX = Length of packet
; Note:	Descriptor Format:
;	Bytes 7:0 - Buffer Address
;	Bytes 9:8 - Length
;	Bytes 13:10 - Flags
;	Bytes 15:14 - Special
net_i8254x_poll:
	push rdi
	push rsi
	push rax

	xor ecx, ecx
	mov cx, [os_rx_desc+8]			; Get the packet length
	mov rdi, os_PacketBuffers
	mov [rdi], word cx

	; Reset the descriptor head and tail
	; TODO - Fix this to actually make use of all the available descriptors
	mov rsi, [os_NetIOBaseMem]
	xor eax, eax
	mov [rsi+I8254X_REG_RDH], eax		; Receive Descriptor Head
	inc eax
	mov [rsi+I8254X_REG_RDT], eax		; Receive Descriptor Tail

	; Reset the Receive Descriptor Buffer Address for a new packet
	mov rdi, os_rx_desc
	mov rax, os_PacketBuffers		; Packet will go here
	add rax, 2				; Room for packet length
	stosd

	pop rax
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8254x_ack_int - Acknowledge an internal interrupt of the Intel 8254x NIC
;  IN:	Nothing
; OUT:	RAX = Ethernet status
net_i8254x_ack_int:
	push rdi

	xor eax, eax
	mov rdi, [os_NetIOBaseMem]
	mov eax, [rdi+I8254X_REG_ICR]

	pop rdi
	ret
; -----------------------------------------------------------------------------


; Maximum packet size
I8254X_MAX_PKT_SIZE	equ 16384

; Register list
I8254X_REG_CTRL		equ 0x0000 ; Control Register
I8254X_REG_STATUS	equ 0x0008 ; Device Status Register
I8254X_REG_CTRLEXT	equ 0x0018 ; Extended Control Register
I8254X_REG_MDIC		equ 0x0020 ; MDI Control Register
I8254X_REG_FCAL		equ 0x0028 ; Flow Control Address Low
I8254X_REG_FCAH		equ 0x002C ; Flow Control Address High
I8254X_REG_FCT		equ 0x0030 ; Flow Control Type
I8254X_REG_VET		equ 0x0038 ; VLAN Ether Type
I8254X_REG_ICR		equ 0x00C0 ; Interrupt Cause Read
I8254X_REG_ITR		equ 0x00C4 ; Interrupt Throttling Register
I8254X_REG_ICS		equ 0x00C8 ; Interrupt Cause Set Register
I8254X_REG_IMS		equ 0x00D0 ; Interrupt Mask Set/Read Register
I8254X_REG_IMC		equ 0x00D8 ; Interrupt Mask Clear Register
I8254X_REG_RCTL		equ 0x0100 ; Receive Control Register
I8254X_REG_FCTTV	equ 0x0170 ; Flow Control Transmit Timer Value
I8254X_REG_TXCW		equ 0x0178 ; Transmit Configuration Word
I8254X_REG_RXCW		equ 0x0180 ; Receive Configuration Word
I8254X_REG_TCTL		equ 0x0400 ; Transmit Control Register
I8254X_REG_TIPG		equ 0x0410 ; Transmit Inter Packet Gap

I8254X_REG_LEDCTL	equ 0x0E00 ; LED Control
I8254X_REG_PBA		equ 0x1000 ; Packet Buffer Allocation

I8254X_REG_RDBAL	equ 0x2800 ; RX Descriptor Base Address Low
I8254X_REG_RDBAH	equ 0x2804 ; RX Descriptor Base Address High
I8254X_REG_RDLEN	equ 0x2808 ; RX Descriptor Length
I8254X_REG_RDH		equ 0x2810 ; RX Descriptor Head
I8254X_REG_RDT		equ 0x2818 ; RX Descriptor Tail
I8254X_REG_RDTR		equ 0x2820 ; RX Delay Timer Register
I8254X_REG_RXDCTL	equ 0x3828 ; RX Descriptor Control
I8254X_REG_RADV		equ 0x282C ; RX Int. Absolute Delay Timer
I8254X_REG_RSRPD	equ 0x2C00 ; RX Small Packet Detect Interrupt

I8254X_REG_TXDMAC	equ 0x3000 ; TX DMA Control
I8254X_REG_TDBAL	equ 0x3800 ; TX Descriptor Base Address Low
I8254X_REG_TDBAH	equ 0x3804 ; TX Descriptor Base Address High
I8254X_REG_TDLEN	equ 0x3808 ; TX Descriptor Length
I8254X_REG_TDH		equ 0x3810 ; TX Descriptor Head
I8254X_REG_TDT		equ 0x3818 ; TX Descriptor Tail
I8254X_REG_TIDV		equ 0x3820 ; TX Interrupt Delay Value
I8254X_REG_TXDCTL	equ 0x3828 ; TX Descriptor Control
I8254X_REG_TADV		equ 0x382C ; TX Absolute Interrupt Delay Value
I8254X_REG_TSPMT	equ 0x3830 ; TCP Segmentation Pad & Min Threshold

I8254X_REG_RXCSUM	equ 0x5000 ; RX Checksum Control
I8254X_REG_MTA		equ 0x5200 ; Multicast Table Array

; Register list for i8254x
I82542_REG_RDTR		equ 0x0108 ; RX Delay Timer Register
I82542_REG_RDBAL	equ 0x0110 ; RX Descriptor Base Address Low
I82542_REG_RDBAH	equ 0x0114 ; RX Descriptor Base Address High
I82542_REG_RDLEN	equ 0x0118 ; RX Descriptor Length
I82542_REG_RDH		equ 0x0120 ; RDH for i82542
I82542_REG_RDT		equ 0x0128 ; RDT for i82542
I82542_REG_TDBAL	equ 0x0420 ; TX Descriptor Base Address Low
I82542_REG_TDBAH	equ 0x0424 ; TX Descriptor Base Address Low
I82542_REG_TDLEN	equ 0x0428 ; TX Descriptor Length
I82542_REG_TDH		equ 0x0430 ; TDH for i82542
I82542_REG_TDT		equ 0x0438 ; TDT for i82542

; CTRL - Control Register (0x0000)
I8254X_CTRL_FD		equ 0x00000001 ; Full Duplex
I8254X_CTRL_LRST	equ 0x00000008 ; Link Reset
I8254X_CTRL_ASDE	equ 0x00000020 ; Auto-speed detection
I8254X_CTRL_SLU		equ 0x00000040 ; Set Link Up
I8254X_CTRL_ILOS	equ 0x00000080 ; Invert Loss of Signal
I8254X_CTRL_SPEED_MASK	equ 0x00000300 ; Speed selection
I8254X_CTRL_SPEED_SHIFT	equ 8
I8254X_CTRL_FRCSPD	equ 0x00000800 ; Force Speed
I8254X_CTRL_FRCDPLX	equ 0x00001000 ; Force Duplex
I8254X_CTRL_SDP0_DATA	equ 0x00040000 ; SDP0 data
I8254X_CTRL_SDP1_DATA	equ 0x00080000 ; SDP1 data
I8254X_CTRL_SDP0_IODIR	equ 0x00400000 ; SDP0 direction
I8254X_CTRL_SDP1_IODIR	equ 0x00800000 ; SDP1 direction
I8254X_CTRL_RST		equ 0x04000000 ; Device Reset
I8254X_CTRL_RFCE	equ 0x08000000 ; RX Flow Ctrl Enable
I8254X_CTRL_TFCE	equ 0x10000000 ; TX Flow Ctrl Enable
I8254X_CTRL_VME		equ 0x40000000 ; VLAN Mode Enable
I8254X_CTRL_PHY_RST	equ 0x80000000 ; PHY reset

; STATUS - Device Status Register (0x0008)
I8254X_STATUS_FD		equ 0x00000001 ; Full Duplex
I8254X_STATUS_LU		equ 0x00000002 ; Link Up
I8254X_STATUS_TXOFF		equ 0x00000010 ; Transmit paused
I8254X_STATUS_TBIMODE		equ 0x00000020 ; TBI Mode
I8254X_STATUS_SPEED_MASK	equ 0x000000C0 ; Link Speed setting
I8254X_STATUS_SPEED_SHIFT	equ 6
I8254X_STATUS_ASDV_MASK		equ 0x00000300 ; Auto Speed Detection
I8254X_STATUS_ASDV_SHIFT	equ 8
I8254X_STATUS_PCI66		equ 0x00000800 ; PCI bus speed
I8254X_STATUS_BUS64		equ 0x00001000 ; PCI bus width
I8254X_STATUS_PCIX_MODE		equ 0x00002000 ; PCI-X mode
I8254X_STATUS_PCIXSPD_MASK	equ 0x0000C000 ; PCI-X speed
I8254X_STATUS_PCIXSPD_SHIFT	equ 14

; CTRL_EXT - Extended Device Control Register (0x0018)
I8254X_CTRLEXT_PHY_INT		equ 0x00000020 ; PHY interrupt
I8254X_CTRLEXT_SDP6_DATA	equ 0x00000040 ; SDP6 data
I8254X_CTRLEXT_SDP7_DATA	equ 0x00000080 ; SDP7 data
I8254X_CTRLEXT_SDP6_IODIR	equ 0x00000400 ; SDP6 direction
I8254X_CTRLEXT_SDP7_IODIR	equ 0x00000800 ; SDP7 direction
I8254X_CTRLEXT_ASDCHK		equ 0x00001000 ; Auto-Speed Detect Chk
I8254X_CTRLEXT_EE_RST		equ 0x00002000 ; EEPROM reset
I8254X_CTRLEXT_SPD_BYPS		equ 0x00008000 ; Speed Select Bypass
I8254X_CTRLEXT_RO_DIS		equ 0x00020000 ; Relaxed Ordering Dis.
I8254X_CTRLEXT_LNKMOD_MASK	equ 0x00C00000 ; Link Mode
I8254X_CTRLEXT_LNKMOD_SHIFT	equ 22

; MDIC - MDI Control Register (0x0020)
I8254X_MDIC_DATA_MASK	equ 0x0000FFFF ; Data
I8254X_MDIC_REG_MASK	equ 0x001F0000 ; PHY Register
I8254X_MDIC_REG_SHIFT	equ 16
I8254X_MDIC_PHY_MASK	equ 0x03E00000 ; PHY Address
I8254X_MDIC_PHY_SHIFT	equ 21
I8254X_MDIC_OP_MASK	equ 0x0C000000 ; Opcode
I8254X_MDIC_OP_SHIFT	equ 26
I8254X_MDIC_R		equ 0x10000000 ; Ready
I8254X_MDIC_I		equ 0x20000000 ; Interrupt Enable
I8254X_MDIC_E		equ 0x40000000 ; Error

; ICR - Interrupt Cause Read (0x00c0)
I8254X_ICR_TXDW		equ 0x00000001 ; TX Desc Written back
I8254X_ICR_TXQE		equ 0x00000002 ; TX Queue Empty
I8254X_ICR_LSC		equ 0x00000004 ; Link Status Change
I8254X_ICR_RXSEQ	equ 0x00000008 ; RX Sequence Error
I8254X_ICR_RXDMT0	equ 0x00000010 ; RX Desc min threshold reached
I8254X_ICR_RXO		equ 0x00000040 ; RX Overrun
I8254X_ICR_RXT0		equ 0x00000080 ; RX Timer Interrupt
I8254X_ICR_MDAC		equ 0x00000200 ; MDIO Access Complete
I8254X_ICR_RXCFG	equ 0x00000400
I8254X_ICR_PHY_INT	equ 0x00001000 ; PHY Interrupt
I8254X_ICR_GPI_SDP6	equ 0x00002000 ; GPI on SDP6
I8254X_ICR_GPI_SDP7	equ 0x00004000 ; GPI on SDP7
I8254X_ICR_TXD_LOW	equ 0x00008000 ; TX Desc low threshold hit
I8254X_ICR_SRPD		equ 0x00010000 ; Small RX packet detected

; RCTL - Receive Control Register (0x0100)
I8254X_RCTL_EN		equ 0x00000002 ; Receiver Enable
I8254X_RCTL_SBP		equ 0x00000004 ; Store Bad Packets
I8254X_RCTL_UPE		equ 0x00000008 ; Unicast Promiscuous Enabled
I8254X_RCTL_MPE		equ 0x00000010 ; Xcast Promiscuous Enabled
I8254X_RCTL_LPE		equ 0x00000020 ; Long Packet Reception Enable
I8254X_RCTL_LBM_MASK	equ 0x000000C0 ; Loopback Mode
I8254X_RCTL_LBM_SHIFT	equ 6
I8254X_RCTL_RDMTS_MASK	equ 0x00000300 ; RX Desc Min Threshold Size
I8254X_RCTL_RDMTS_SHIFT	equ 8
I8254X_RCTL_MO_MASK	equ 0x00003000 ; Multicast Offset
I8254X_RCTL_MO_SHIFT	equ 12
I8254X_RCTL_BAM		equ 0x00008000 ; Broadcast Accept Mode
I8254X_RCTL_BSIZE_MASK	equ 0x00030000 ; RX Buffer Size
I8254X_RCTL_BSIZE_SHIFT	equ 16
I8254X_RCTL_VFE		equ 0x00040000 ; VLAN Filter Enable
I8254X_RCTL_CFIEN	equ 0x00080000 ; CFI Enable
I8254X_RCTL_CFI		equ 0x00100000 ; Canonical Form Indicator Bit
I8254X_RCTL_DPF		equ 0x00400000 ; Discard Pause Frames
I8254X_RCTL_PMCF	equ 0x00800000 ; Pass MAC Control Frames
I8254X_RCTL_BSEX	equ 0x02000000 ; Buffer Size Extension
I8254X_RCTL_SECRC	equ 0x04000000 ; Strip Ethernet CRC

; TCTL - Transmit Control Register (0x0400)
I8254X_TCTL_EN		equ 0x00000002 ; Transmit Enable
I8254X_TCTL_PSP		equ 0x00000008 ; Pad short packets
I8254X_TCTL_SWXOFF	equ 0x00400000 ; Software XOFF Transmission

; PBA - Packet Buffer Allocation (0x1000)
I8254X_PBA_RXA_MASK	equ 0x0000FFFF ; RX Packet Buffer
I8254X_PBA_RXA_SHIFT	equ 0
I8254X_PBA_TXA_MASK	equ 0xFFFF0000 ; TX Packet Buffer
I8254X_PBA_TXA_SHIFT	equ 16

; Flow Control Type
I8254X_FCT_TYPE_DEFAULT	equ 0x8808

; === TX Descriptor fields ===

; TX Packet Length (word 2)
I8254X_TXDESC_LEN_MASK	equ 0x0000ffff

; TX Descriptor CMD field (word 2)
I8254X_TXDESC_IDE	equ 0x80000000 ; Interrupt Delay Enable
I8254X_TXDESC_VLE	equ 0x40000000 ; VLAN Packet Enable
I8254X_TXDESC_DEXT	equ 0x20000000 ; Extension
I8254X_TXDESC_RPS	equ 0x10000000 ; Report Packet Sent
I8254X_TXDESC_RS	equ 0x08000000 ; Report Status
I8254X_TXDESC_IC	equ 0x04000000 ; Insert Checksum
I8254X_TXDESC_IFCS	equ 0x02000000 ; Insert FCS
I8254X_TXDESC_EOP	equ 0x01000000 ; End Of Packet

; TX Descriptor STA field (word 3)
I8254X_TXDESC_TU	equ 0x00000008 ; Transmit Underrun
I8254X_TXDESC_LC	equ 0x00000004 ; Late Collision
I8254X_TXDESC_EC	equ 0x00000002 ; Excess Collisions
I8254X_TXDESC_DD	equ 0x00000001 ; Descriptor Done

; === RX Descriptor fields ===

; RX Packet Length (word 2)
I8254X_RXDESC_LEN_MASK	equ 0x0000ffff

; RX Descriptor STA field (word 3)
I8254X_RXDESC_PIF	equ 0x00000080 ; Passed In-exact Filter
I8254X_RXDESC_IPCS	equ 0x00000040 ; IP cksum calculated
I8254X_RXDESC_TCPCS	equ 0x00000020 ; TCP cksum calculated
I8254X_RXDESC_VP	equ 0x00000008 ; Packet is 802.1Q
I8254X_RXDESC_IXSM	equ 0x00000004 ; Ignore cksum indication
I8254X_RXDESC_EOP	equ 0x00000002 ; End Of Packet
I8254X_RXDESC_DD	equ 0x00000001 ; Descriptor Done

; =============================================================================
; EOF
