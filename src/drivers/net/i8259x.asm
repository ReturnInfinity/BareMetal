; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Intel 8259x/X540/X550 10 Gigabit Ethernet Driver
; =============================================================================


; -----------------------------------------------------------------------------
; Initialize an Intel 8259x NIC
;  IN:	RDX = Packed Bus address (as per syscalls/bus.asm)
net_i8259x_init:
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

	mov ax, 0x8259			; Driver tag for i8259x
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

	; Get the MAC address
	pop rsi				; Restore the base
	push rdi
	add rdi, 8
	mov eax, [rsi+i8259x_RAL]	; RAL
	stosb
	shr eax, 8
	stosb
	shr eax, 8
	stosb
	shr eax, 8
	stosb
	mov eax, [rsi+i8259x_RAH]	; RAH
	stosb
	shr eax, 8
	stosb
	pop rdi

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
	call net_i8259x_reset

	; Store call addresses
	mov rax, net_i8259x_config
	mov [rdi+nt_config], rax
	mov rax, net_i8259x_transmit
	mov [rdi+nt_transmit], rax
	mov rax, net_i8259x_poll
	mov [rdi+nt_poll], rax

net_i8259x_init_error:

	pop rax
	pop rcx
	pop rdx
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8259x_reset - Reset an Intel 8259x NIC
;  IN:	Nothing
; OUT:	Nothing, all registers preserved
net_i8259x_reset:
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

	; Disable Interrupts (4.6.3.1)
	xor eax, eax
	mov [rsi+i8259x_EIMS], eax
	mov eax, i8259x_IRQ_CLEAR_MASK
	mov [rsi+i8259x_EIMC], eax
	mov eax, [rsi+i8259x_EICR]

	; Issue a global reset (4.6.3.2)
	mov eax, i8259x_CTRL_RST_MASK	; Load the mask for a software reset and link reset
	mov [rsi+i8259x_CTRL], eax	; Write the reset value
net_i8259x_reset_wait:
	mov eax, [rsi+i8259x_CTRL]	; Read CTRL
	jnz net_i8259x_reset_wait	; Wait for it to read back as 0x0

	; Wait 10ns
	mov rax, 10000
	call b_delay

	; Disable Interrupts again (4.6.3.1)
	xor eax, eax
	mov [rsi+i8259x_EIMS], eax
	mov eax, i8259x_IRQ_CLEAR_MASK
	mov [rsi+i8259x_EIMC], eax
	mov eax, [rsi+i8259x_EICR]

	; Wait for EEPROM auto read completion (4.6.3)
	mov eax, [rsi+i8259x_EEC]	; Read current value
	bts eax, 9			; i8259x_EEC_ARD
	mov [rsi+i8259x_EEC], eax	; Write the new value
net_i8259x_reset_eeprom_wait:
	mov eax, [rsi+i8259x_EEC]	; Read current value
	bt eax, 9			; i8259x_EEC_ARD
	jnc net_i8259x_reset_eeprom_wait	; If not equal, keep waiting

	; Wait for DMA initialization done (4.6.3)
	mov eax, [rsi+i8259x_RDRXCTL]	; Read current value
	bts eax, 3			; i8259x_RDRXCTL_DMAIDONE
	mov [rsi+i8259x_RDRXCTL], eax	; Write the new value
net_i8259x_reset_dma_wait:
	mov eax, [rsi+i8259x_RDRXCTL]	; Read current value
	bt eax, 3			; i8259x_RDRXCTL_DMAIDONE
	jnc net_i8259x_reset_dma_wait	; If not equal, keep waiting

	; Set up the PHY and the link (4.6.4)
	; mov eax, [rsi+i8259x_AUTOC]
	; and eax, 0x0000E000		; Set LMS (bits 15:13) for KX/KX4/KR auto-negotiation enable
	; or eax, 0x00006000		; Set KX/KX4/KR auto-negotiation enable
	; mov [rsi+i8259x_AUTOC], eax
	; mov eax, [rsi+i8259x_AUTOC]
	; and eax, 0x00000180		; Set 10G_PMA_PMD_PARALLEL (bits 8:7)
	; mov [rsi+i8259x_AUTOC], eax

	; mov rax, 20000			; Wait 20ms (20000µs)
	; call b_delay			; Delay for 20ms

	mov eax, [rsi+i8259x_AUTOC]
	bts eax, 12			; Restart_AN
	mov [rsi+i8259x_AUTOC], eax

	; Initialize all statistical counters (4.6.5)
	; These registers are cleared by the device after they are read
	mov eax, [rsi+i8259x_GPRC]	; RX packets
	mov eax, [rsi+i8259x_GPTC]	; TX packets
	mov eax, [rsi+i8259x_GORCL]
	mov eax, [rsi+i8259x_GORCH]	; RX bytes = GORCL + (GORCH << 32)
	mov eax, [rsi+i8259x_GOTCL]
	mov eax, [rsi+i8259x_GOTCH]	; TX bytes = GOTCL + (GOTCH << 32)

	; Create RX descriptors
	push rdi
	mov ecx, i8259x_MAX_DESC
	xor eax, eax
	mov al, byte [os_net_icount]
	shl eax, 15
	mov rdi, os_rx_desc
	add rdi, rax
net_i8259x_reset_nextdesc:	
	mov rax, os_PacketBuffers	; Default packet will go here
	stosq
	xor eax, eax
	stosq
	dec ecx
	jnz net_i8259x_reset_nextdesc
	pop rdi

	; Initialize receive (4.6.7)
	; Set RX to disabled
	xor eax, eax			; RXEN = 0
	mov [rsi+i8259x_RXCTRL], eax
;	; Set packet buffer
;	mov eax, 32768
;	mov [rsi+i8259x_RXPBSIZE], eax
	; Set Max packet size
	mov eax, 9000			; 9000 bytes
	shl eax, 16			; Shift to bits 31:16
	mov [rsi+i8259x_MAXFRS], eax
	; Enable Jumbo Frames
	mov eax, [rsi+i8259x_HLREG0]
	or eax, 1 << i8259x_HLREG0_JUMBOEN
	mov [rsi+i8259x_HLREG0], eax
	; Enable CRC offloading
	mov eax, [rsi+i8259x_HLREG0]
	or eax, 1 << i8259x_HLREG0_RXCRCSTRP
	mov [rsi+i8259x_HLREG0], eax
	mov eax, [rsi+i8259x_RDRXCTL]
	or eax, 1 << i8259x_RDRXCTL_CRCSTRIP
	mov [rsi+i8259x_RDRXCTL], eax
	; Accept broadcast packets
	mov eax, [rsi+i8259x_FCTRL]
	or eax, i8259x_FCTRL_BAM
	mov [rsi+i8259x_FCTRL], eax
	; Enable Advanced RX descriptors
	mov eax, [rsi+i8259x_SRRCTL]
	and eax, 0xF1FFFFFF		; Clear bits 27:25 for DESCTYPE
;	or eax, 0x02000000		; Bits 27:25 = 001 for Advanced desc one buffer
	bts eax, 28			; i8259x_SRRCTL_DROP_EN
	mov [rsi+i8259x_SRRCTL], eax
	; Set up RX descriptor ring 0
	xor eax, eax
	mov al, byte [os_net_icount]
	shl eax, 15
	add rax, os_rx_desc
	mov [rsi+i8259x_RDBAL], eax
	shr rax, 32
	mov [rsi+i8259x_RDBAH], eax
	mov eax, i8259x_MAX_DESC * 16
	mov [rsi+i8259x_RDLEN], eax
	xor eax, eax
	mov [rsi+i8259x_RDH], eax
	mov [rsi+i8259x_RDT], eax
	; Set bit 16 of CTRL_EXT (Last line in 4.6.7)
	mov eax, [rsi+i8259x_CTRL_EXT]
	bts eax, 16
	mov [rsi+i8259x_CTRL_EXT], eax
	; Clear bit 12 of DCA_RXCTRL (Last line in 4.6.7)
	mov eax, [rsi+i8259x_DCA_RXCTRL]
	btc eax, 12
	mov [rsi+i8259x_DCA_RXCTRL], eax
	; Enable RX
	mov eax, 1			; RXEN = 1
	mov [rsi+i8259x_RXCTRL], eax	; Enable receive

	; Enable Multicast
	mov eax, 0xFFFFFFFF
	mov [rsi+i8259x_MTA], eax

	; Enable the RX queue
	mov eax, [rsi+i8259x_RXDCTL]
	or eax, 0x02000000
	mov [rsi+i8259x_RXDCTL], eax
net_i8259x_init_rx_enable_wait:
	mov eax, [rsi+i8259x_RXDCTL]
	bt eax, 25
	jnc net_i8259x_init_rx_enable_wait
	xor eax, eax
	mov [rsi+i8259x_RDH], eax
	mov eax, i8259x_MAX_DESC - 1
	mov [rsi+i8259x_RDT], eax

; 	; Set SECRXCTRL_RX_DIS
; 	mov eax, [rsi+i8259x_SECRXCTRL]
; 	bts eax, i8259x_SECRXCTRL_RX_DIS
; 	mov [rsi+i8259x_SECRXCTRL], eax
; 	; Poll SECRXSTAT_SECRX_RDY
; net_i8259x_init_rx_secrx_rdy_wait:
; 	mov eax, [rsi+i8259x_SECRXSTAT]
; 	bt eax, i8259x_SECRXSTAT_SECRX_RDY
; 	jnc net_i8259x_init_rx_secrx_rdy_wait

; 	; Clear SECRXCTRL.SECRX_DIS
; 	mov eax, [rsi+i8259x_SECRXCTRL]
; 	btc eax, i8259x_SECRXCTRL_SECRX_DIS
; 	mov [rsi+i8259x_SECRXCTRL], eax

	; Initialize transmit (4.6.8)
	; Enable CRC offload and small packet padding
	mov eax, [rsi+i8259x_HLREG0]
	or eax, 1 << i8259x_HLREG0_TXCRCEN | 1 << i8259x_HLREG0_TXPADEN
	mov [rsi+i8259x_HLREG0], eax
	; Set RTTDCS_ARBDIS
	mov eax, [rsi+i8259x_RTTDCS]
	bts eax, i8259x_RTTDCS_ARBDIS
	mov [rsi+i8259x_RTTDCS], eax
	; Configure Max allowed number of bytes requests (Bits 11:0)
	mov eax, 0x00000FFF
	mov [rsi+i8259x_DTXMXSZRQ], eax
	; Set packet buffer size
	mov eax, 32768
	mov [rsi+i8259x_TXPBSIZE], eax
	; Clear RTTDCS_ARBDIS
	mov eax, [rsi+i8259x_RTTDCS]
	btc eax, i8259x_RTTDCS_ARBDIS
	mov [rsi+i8259x_RTTDCS], eax
	; Set up TX descriptor ring 0
	xor eax, eax
	mov al, byte [os_net_icount]
	shl eax, 15
	add rax, os_tx_desc
	mov [rsi+i8259x_TDBAL], eax	; Bits 6:0 are ignored, memory alignment at 128bytes
	shr rax, 32
	mov [rsi+i8259x_TDBAH], eax
	mov eax, i8259x_MAX_DESC * 16
	mov [rsi+i8259x_TDLEN], eax
	xor eax, eax
	mov [rsi+i8259x_TDH], eax
	mov [rsi+i8259x_TDT], eax
	; Program TXDCTL with TX descriptor write back policy
	mov eax, [rsi+i8259x_TXDCTL]
	and eax, 0xFF808080		; Clear bits 22:16, 14:8, 6:0
;	or eax, 0x0040824		; Set bits 22:16, 14:8, 6:0
	mov [rsi+i8259x_TXDCTL], eax
	; Enable Transmit path
	mov eax, [rsi+i8259x_DMATXCTL]
	or eax, 1			; Transmit Enable, bit 0 TE
	mov [rsi+i8259x_DMATXCTL], eax
	; Enable the TX queue
	mov eax, [rsi+i8259x_TXDCTL]
	bts eax, 25
	mov [rsi+i8259x_TXDCTL], eax
net_i8259x_init_tx_enable_wait:
	mov eax, [rsi+i8259x_TXDCTL]
	bt eax, 25
	jnc net_i8259x_init_tx_enable_wait

	; ; Enable interrupts (4.6.3.1)
	; ; Step 1:-
	; mov eax, [rsi+0x00898]		; Get Ixgbe_GPIE
	; or eax, 0x00000010		; GPIE_MSIx_Mode
	; or eax, 0x80000000		; GPIE_PBA_SUPPORT
	; or eax, 0x40000000		; GPIE_EIAME
	; mov [rsi+0x00898], eax		; Set Ixgbe_GPIE

	; ; Step 2:-	We don't use the minimum threshold interrupt

	; ; Step 3:-
	; mov eax, 0x0000FFFF
	; mov [rsi+i8259x_EIAC], eax

	; ; Step 4:- In our case we prefer to not auto-mask the interrupts
	; ; TODO- Set EITR

	; ; Step 5:-
	; mov eax, [rsi+i8259x_EIMS]
	; or eax, 0x00000001
	; mov [rsi+i8259x_EIMS], eax


; DEBUG - Enable Promiscuous mode
	mov eax, [rsi+i8259x_FCTRL]
	or eax, 1 << i8259x_FCTRL_MPE | 1 << i8259x_FCTRL_UPE
	mov [rsi+i8259x_FCTRL], eax

	; Set Driver Loaded bit
	mov eax, [rsi+i8259x_CTRL_EXT]
	or eax, 1 << i8259x_CTRL_EXT_DRV_LOAD
	mov [rsi+i8259x_CTRL_EXT], eax

	pop rax
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8259x_config - 
;  IN:	RAX = Base address to store packets
;	RDX = Interface ID
; OUT:	Nothing
net_i8259x_config:
	push rdi
	push rcx
	push rax

	mov rdi, [rdx+nt_rx_desc]
	mov ecx, i8259x_MAX_DESC
	call os_virt_to_phys
net_i8259x_config_next_record:
	stosq
	add rdi, 8
	add rax, 2048
	dec ecx
	cmp ecx, 0
	jnz net_i8259x_config_next_record

	pop rax
	pop rcx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8259x_transmit - Transmit a packet via an Intel 8259x NIC
;  IN:	RSI = Location of packet
;	RDX = Interface ID
;	RCX = Length of packet
; OUT:	Nothing
; Note:	Transmit Descriptor (TDESC) Layout - Legacy Mode (7.2.3.2.2):
;	Bits 63:0 - Buffer Address
;	Bits 95:64 - CMD (Bits 31:24) / CSO (Bits 23:16) / Length (Bits 15:0)
;	Bits 127:96 - VLAN (Bits 63:48) / CSS (Bits 47:40) / Reserved (Bits 39:36) / STA (Bits 35:32)
net_i8259x_transmit:
	push rdi
	push rax

	mov rdi, [rdx+nt_tx_desc]	; Transmit Descriptor Base Address

	; Calculate the descriptor to write to
	mov eax, [rdx+nt_tx_tail]	; Get tx_lasttail
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

	; Increment i8259x_tx_lasttail and the Transmit Descriptor Tail
	pop rax				; Restore lasttail
	add eax, 1
	and eax, i8259x_MAX_DESC - 1
	mov [rdx+nt_tx_tail], eax	; Set tx_lasttail
	mov rdi, [rdx+nt_base]		; Load the base MMIO of the NIC
	mov [rdi+i8259x_TDT], eax	; TDL - Transmit Descriptor Tail

	; TDESC.STA.DD (bit 32) should be 1 once the hardware has sent the packet

	pop rax
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_i8259x_poll - Polls the Intel 8259x NIC for a received packet
;  IN:	RDI = Location to store packet
;	RDX = Interface ID
; OUT:	RCX = Length of packet
; Note: Receive Descriptor (RDESC) Layout - Legacy Mode (7.1.5):
;	Bits 63:0 - Buffer Address
;	Bits 95:64 - Fragment Checksum (Bits 31:16) / Length (Bits 15:0)
;	Bits 127:96 - VLAN (Bits 63:48) / Errors (Bits 47:40) / STA (Bits 39:32)
net_i8259x_poll:
	push rsi			; Used for the base MMIO of the NIC
	push rbx
	push rax

	mov rdi, [rdx+nt_rx_desc]
	mov rsi, [rdx+nt_base]		; Load the base MMIO of the NIC

	; Calculate the descriptor to read from
	mov eax, [rdx+nt_rx_head]	; Get rx_lasthead
	shl eax, 4			; Quick multiply by 16
	add rdi, rax			; Add offset to RDI
	mov rbx, [rdi]
	add rdi, 8			; Offset to bytes received
	; Todo: read all 64 bits. check status bit for DD
	xor ecx, ecx			; Clear RCX
	mov cx, [rdi]			; Get the packet length
	cmp cx, 0
	je net_i8259x_poll_end		; No data? Bail out

	xor eax, eax
	stosq				; Clear the descriptor length and status
	mov rdi, rbx

	; Increment i8259x_rx_lasthead and the Receive Descriptor Tail
	mov eax, [rdx+nt_rx_head]	; Get rx_lasthead
	add eax, 1
	and eax, i8259x_MAX_DESC - 1
	mov [rdx+nt_rx_head], eax	; Set rx_lasthead

	mov eax, [rsi+i8259x_RDT]	; Read the current Receive Descriptor Tail
	add eax, 1			; Add 1 to the Receive Descriptor Tail
	and eax, i8259x_MAX_DESC - 1
	mov [rsi+i8259x_RDT], eax	; Write the updated Receive Descriptor Tail

net_i8259x_poll_end:
	pop rax
	pop rbx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; Constants
i8259x_MAX_DESC		equ 2048	; Must be 16, 32, 64, 128, etc. Each descriptor is 16 bytes

; Register list (All registers should be accessed as 32-bit values)

; General Control Registers
i8259x_CTRL		equ 0x00000 ; Device Control Register
i8259x_CTRL_Legacy	equ 0x00004 ; Copy of Device Control Register
i8259x_STATUS		equ 0x00008 ; Device Status Register
i8259x_CTRL_EXT		equ 0x00018 ; Extended Device Control Register
i8259x_ESDP		equ 0x00020 ; Extended SDP Control
i8259x_I2CCTL		equ 0x00028 ; I2C Control
i8259x_LEDCTL		equ 0x00200 ; LED Control
i8259x_EXVET		equ 0x05078 ; Extended VLAN Ether Type

; EEPROM / Flash Registers
i8259x_EEC		equ 0x10010 ; EEPROM/Flash Control Register
i8259x_EERD		equ 0x10014 ; EEPROM Read Register
i8259x_FLA		equ 0x1001C ; Flash Access Register
i8259x_EEMNGDATA	equ 0x10114 ; Manageability EEPROM Read/ Write Data
i8259x_FLMNGCTL		equ 0x10118 ; Manageability Flash Control Register
i8259x_FLMNGDATA	equ 0x1011C ; Manageability Flash Read Data
i8259x_FLOP		equ 0x1013C ; Flash Opcode Register
i8259x_GRC		equ 0x10200 ; General Receive Control

; Flow Control Registers

; PCIe Registers
i8259x_GCR		equ 0x11000 ; PCIe Control Register
i8259x_GSCL_0		equ 0x11020 ; PCIe Statistic Control Register #0
i8259x_GSCL_1		equ 0x11010 ; PCIe Statistic Control Register #1
i8259x_GSCL_2		equ 0x11014 ; PCIe Statistic Control Register #2
;i8259x_GSCL_3
;i8259x_GSCL_4
i8259x_GSCL_5		equ 0x11030 ; PCIe Statistic Control Register #5
;i8259x_GSCL_6
;i8259x_GSCL_7
;i8259x_GSCL_8
i8259x_FACTPS		equ 0x10150 ; Function Active and Power State to Manageability
i8259x_PCIEPHYADR	equ 0x11040 ; PCIe PHY Address Register
i8259x_PCIEPHYDAT	equ 0x11044 ; PCIe PHY Data Register

; Interrupt Registers
i8259x_EICR		equ 0x00800 ; Extended Interrupt Cause Register
i8259x_EICS		equ 0x00808 ; Extended Interrupt Cause Set Register
i8259x_EIMS		equ 0x00880 ; Extended Interrupt Mask Set / Read Register
i8259x_EIMC		equ 0x00888 ; Extended Interrupt Mask Clear Register
i8259x_EIAC		equ 0x00810 ; Extended Interrupt Auto Clear Register
i8259x_EIAM		equ 0x00890 ; Extended Interrupt Auto Mask Enable Register

; MSI-X Table Registers
i8259x_PBACL		equ 0x110C0 ; MSI-X PBA Clear

; Receive Registers
i8259x_FCTRL		equ 0x05080 ; Filter Control Register
i8259x_MTA		equ 0x05200 ; Multicast Table Array
i8259x_RAL		equ 0x0A200 ; Receive Address Low (Lower 32-bits of 48-bit address)
i8259x_RAH		equ 0x0A204 ; Receive Address High (Upper 16-bits of 48-bit address). Bit 31 should be set for Address Valid

; Receive DMA Registers
i8259x_RDBAL		equ 0x01000 ; Receive Descriptor Base Address Low
i8259x_RDBAH		equ 0x01004 ; Receive Descriptor Base Address High
i8259x_RDLEN		equ 0x01008 ; Receive Descriptor Length
i8259x_RDH		equ 0x01010 ; Receive Descriptor Head
i8259x_RDT		equ 0x01018 ; Receive Descriptor Tail
i8259x_RXDCTL		equ 0x01028 ; Receive Descriptor Control
i8259x_RDRXCTL		equ 0x02F00 ; Receive DMA Control Register
i8259x_SRRCTL		equ 0x02100 ; Split Receive Control Registers
i8259x_RXCTRL		equ 0x03000 ; Receive Control Register
i8259x_RXPBSIZE		equ 0x03C00 ; Receive Packet Buffer Size

; Transmit Registers
i8259x_DMATXCTL		equ 0x04A80 ; DMA Tx Control
i8259x_TDBAL		equ 0x06000 ; Transmit Descriptor Base Address Low
i8259x_TDBAH		equ 0x06004 ; Transmit Descriptor Base Address High
i8259x_TDLEN		equ 0x06008 ; Transmit Descriptor Length (Bits 19:0 in bytes, 128-byte aligned)
i8259x_TDH		equ 0x06010 ; Transmit Descriptor Head (Bits 15:0)
i8259x_TDT		equ 0x06018 ; Transmit Descriptor Tail (Bits 15:0)
i8259x_TXDCTL		equ 0x06028 ; Transmit Descriptor Control (Bit 25 - Enable)
i8259x_DTXMXSZRQ	equ 0x08100 ; DMA Tx TCP Max Allow Size Requests
i8259x_TXPBSIZE		equ 0x0CC00 ; Transmit Packet Buffer Size

; DCB Registers
i8259x_RTTDCS		equ 0x04900 ; DCB Transmit Descriptor Plane Control and Status

; DCA Registers
i8259x_DCA_RXCTRL	equ 0x02200 ; Rx DCA Control Register

; Security Registers
i8259x_SECRXCTRL	equ 0x08D00 ; Security Rx Control
i8259x_SECRXSTAT	equ 0x08D04 ; Security Rx Status

; LinkSec Registers

; IPsec Registers

; Timers Registers

; FCoE Registers

; Flow Director Registers

; Global Status / Statistics Registers

; Flow Programming Registers

; MAC Registers
i8259x_HLREG0		equ 0x04240 ; MAC Core Control 0 Register
i8259x_HLREG1		equ 0x04244 ; MAC Core Status 1 Register
i8259x_MAXFRS		equ 0x04268 ; Max Frame Size
i8259x_AUTOC		equ 0x042A0 ; Auto-Negotiation Control Register
i8259x_AUTOC2		equ 0x042A8 ; Auto-Negotiation Control Register 2
i8259x_LINKS		equ 0x042A4 ; Link Status Register
i8259x_LINKS2		equ 0x04324 ; Link Status Register 2

; Statistic Registers
i8259x_GPRC		equ 0x04074 ; Good Packets Received Count
i8259x_BPRC		equ 0x04078 ; Broadcast Packets Received Count
i8259x_MPRC		equ 0x0407C ; Multicast Packets Received Count
i8259x_GPTC		equ 0x04080 ; Good Packets Transmitted Count
i8259x_GORCL		equ 0x04088 ; Good Octets Received Count Low
i8259x_GORCH		equ 0x0408C ; Good Octets Received Count High
i8259x_GOTCL		equ 0x04090 ; Good Octets Transmitted Count Low
i8259x_GOTCH		equ 0x04094 ; Good Octets Transmitted Count High

; Wake-Up Control Registers

; Management Filters Registers

; Time Sync (IEEE 1588) Registers

; Virtualization PF Registers




; CTRL (Device Control Register, 0x00000 / 0x00004, RW) Bit Masks
i8259x_CTRL_MSTR_DIS	equ 2 ; PCIe Master Disable
i8259x_CTRL_LRST	equ 3 ; Link Reset
i8259x_CTRL_RST		equ 26 ; Device Reset
; All other bits are reserved and should be written as 0
i8259x_CTRL_RST_MASK	equ 1 << i8259x_CTRL_LRST | 1 << i8259x_CTRL_RST

; STATUS (Device Status Register, 0x00008, RO) Bit Masks
i8259x_STATUS_LINKUP	equ 7 ; Linkup Status Indication
i8259x_STATUS_MASEN	equ 19 ; This is a status bit of the appropriate CTRL.PCIe Master Disable bit.
; All other bits are reserved and should be written as 0

; CTRL_EXT (Extended Device Control Register, 0x00018, RW) Bit Masks
i8259x_CTRL_EXT_DRV_LOAD	equ 28 ; Driver loaded and the corresponding network interface is enabled

; RDRXCTL (Receive DMA Control Register, 0x02F00, RW) Bit Masks
i8259x_RDRXCTL_CRCSTRIP	equ 1 ; Rx CRC Strip indication to the Rx DMA unit. Must be same as HLREG0.RXCRCSTRP
i8259x_RDRXCTL_DMAIDONE	equ 3 ; DMA Init Done - 1 when DMA init is done

; RXCTRL (Receive Control Register, 0x03000, RW) Bit Masks
i8259x_RXCTRL_RXEN	equ 0 ; Receive Enable
; All other bits are reserved and should be written as 0

; RTTDCS (DCB Transmit Descriptor Plane Control and Status, 0x04900, RW) Bit Masks
i8259x_RTTDCS_ARBDIS	equ 6 ; DCB Arbiters Disable

; HLREG0 (MAC Core Control 0 Register, 0x04240, RW) Bit Masks
i8259x_HLREG0_TXCRCEN	equ 0 ; Tx CRC Enable - 1 by default
i8259x_HLREG0_RXCRCSTRP	equ 1 ; Rx CRC STRIP - 1 by default
i8259x_HLREG0_JUMBOEN	equ 2 ; Jumbo Frame Enable - size is defined by MAXFRS
i8259x_HLREG0_TXPADEN	equ 10 ; Tx Pad Frame Enable (pads to at least 64 bytes)
i8259x_HLREG0_LPBK	equ 16 ; Loopback Enable - 0 is default

; LINKS (Link Status Register, 0x042A4, RO)
i8259x_LINKS_LinkStatus	equ 7 ; 1 - Link is up
i8259x_LINKS_LINK_SPEED	equ 28 ; 0 - 1GbE, 1 - 10GbE - Bit 29 must be 1 for this to be valid
i8259x_LINKS_Link_Up	equ 30 ; 1 - Link is up

; FCTRL (Filter Control Register, 0x05080, RW) Bit Masks
i8259x_FCTRL_SBP	equ 1 ; Store Bad Packets
i8259x_FCTRL_MPE	equ 8 ; Multicast Promiscuous Enable
i8259x_FCTRL_UPE	equ 9 ; Unicast Promiscuous Enable
i8259x_FCTRL_BAM	equ 10 ; Broadcast Accept Mode

; SECRXCTRL (Security Rx Control, 0x08D00, RW)
i8259x_SECRXCTRL_SECRX_DIS	equ 0 ; Rx Security Offload Disable Bit.
i8259x_SECRXCTRL_RX_DIS		equ 1 ; Disable Sec Rx Path

; SECRXSTAT (Security Rx Status, 0x08D04, RO)
i8259x_SECRXSTAT_SECRX_RDY	equ 0 ; Rx security block ready for mode change.

; TODO Change bit masks to actual bits
; EEC Bit Masks
i8259x_EEC_SK		equ 0x00000001 ; EEPROM Clock
i8259x_EEC_CS		equ 0x00000002 ; EEPROM Chip Select
i8259x_EEC_DI		equ 0x00000004 ; EEPROM Data In
i8259x_EEC_DO		equ 0x00000008 ; EEPROM Data Out
i8259x_EEC_FWE_MASK	equ 0x00000030 ; FLASH Write Enable
i8259x_EEC_FWE_DIS	equ 0x00000010 ; Disable FLASH writes
i8259x_EEC_FWE_EN	equ 0x00000020 ; Enable FLASH writes
i8259x_EEC_FWE_SHIFT	equ 4
i8259x_EEC_REQ		equ 0x00000040 ; EEPROM Access Request
i8259x_EEC_GNT		equ 0x00000080 ; EEPROM Access Grant
i8259x_EEC_PRES		equ 0x00000100 ; EEPROM Present
i8259x_EEC_ARD		equ 0x00000200 ; EEPROM Auto Read Done
i8259x_EEC_FLUP		equ 0x00800000 ; Flash update command
i8259x_EEC_SEC1VAL	equ 0x02000000 ; Sector 1 Valid
i8259x_EEC_FLUDONE	equ 0x04000000 ; Flash update done

; EEC Misc
; EEPROM Addressing bits based on type (0-small, 1-large)
i8259x_EEC_ADDR_SIZE	equ 0x00000400
i8259x_EEC_SIZE		equ 0x00007800 ; EEPROM Size
i8259x_EERD_MAX_ADDR	equ 0x00003FFF ; EERD allows 14 bits for addr

i8259x_IRQ_CLEAR_MASK	equ 0xFFFFFFFF

; =============================================================================
; EOF