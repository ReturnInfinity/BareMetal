; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2020 Return Infinity -- see LICENSE.TXT
;
; Network Functions
; =============================================================================


; -----------------------------------------------------------------------------
; b_net_status -- Check if network access is available
;  IN:	Nothing
; OUT:	RAX = MAC Address if net is enabled, otherwise 0
b_net_status:
	push rsi
	push rcx

	cld
	xor eax, eax
	cmp byte [os_NetEnabled], 0
	je b_net_status_end

	mov ecx, 6
	mov rsi, os_NetMAC
b_net_status_loadMAC:
	shl rax, 8
	lodsb
	sub ecx, 1
	test ecx, ecx
	jnz b_net_status_loadMAC

b_net_status_end:
	pop rcx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_net_tx -- Transmit a packet via the network
;  IN:	RSI = Memory location where packet is stored
;	RCX = Length of packet
; OUT:	Nothing. All registers preserved
b_net_tx:
	push rcx
	push rax

	cmp byte [os_NetEnabled], 1	; Check if networking is enabled
	jne b_net_tx_fail
	cmp rcx, 64			; An net packet must be at least 64 bytes
	jge b_net_tx_maxcheck
	mov rcx, 64			; If it was below 64 then set to 64
	; FIXME - OS should pad the packet with 0's before sending if less than 64

b_net_tx_maxcheck:
	cmp rcx, 1522			; Fail if more than 1522 bytes
	jg b_net_tx_fail

	mov rax, os_NetLock		; Lock the net so only one send can happen at a time
	call b_smp_lock

	inc qword [os_net_TXPackets]
	add qword [os_net_TXBytes], rcx
	call qword [os_net_transmit]	; Call the driver

	mov rax, os_NetLock
	call b_smp_unlock

b_net_tx_fail:
	pop rax
	pop rcx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_net_rx -- Polls the network for received data
;  IN:	RDI = Memory location where packet will be stored
; OUT:	RCX = Length of packet, 0 if no data
;	All other registers preserved
b_net_rx:
	push rdi
	push rsi
	push rax

	xor ecx, ecx

	cmp byte [os_NetEnabled], 1
	jne b_net_rx_fail

	mov rsi, os_PacketBuffers	; Packet exists here
	mov ax, word [rsi]		; Grab the packet length
	test ax, ax			; Anything there?
	jz b_net_rx_fail		; If not, bail out
	mov word [rsi], cx		; Clear the packet length
	mov cx, ax			; Save the count
	add rsi, 2			; Skip the packet length word
	push rcx
	rep movsb			; Copy packet to new memory
	pop rcx

b_net_rx_fail:

	pop rax
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_net_ack_int -- Acknowledge an interrupt within the NIC
;  IN:	Nothing
; OUT:	RAX = Type of interrupt trigger
;	All other registers preserved
b_net_ack_int:
	call qword [os_net_ackint]

	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_net_rx_from_interrupt -- Polls the network for received data
;  IN:	RDI = Memory location where packet will be stored
; OUT:	RCX = Length of packet
;	All other registers preserved
b_net_rx_from_interrupt:
	call qword [os_net_poll]	; Call the driver
	add qword [os_net_RXPackets], 1
	add qword [os_net_RXBytes], rcx

	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
