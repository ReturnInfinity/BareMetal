; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
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

b_net_tx_maxcheck:
	cmp rcx, 1522			; Fail if more than 1522 bytes
	jg b_net_tx_fail

	mov rax, os_NetLock		; Lock the net so only one send can happen at a time
	call b_smp_lock

	; Calculate where in physical memory the data should be read from
	xchg rax, rsi
	call os_virt_to_phys
	xchg rax, rsi

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

	cmp byte [os_NetEnabled], 1	; Check if networking is enabled
	jne b_net_rx_nodata

	call qword [os_net_poll]	; Call the driver
	cmp cx, 0
	je b_net_rx_nodata
	inc qword [os_net_TXPackets]
	add qword [os_net_TXBytes], rcx

	mov rsi, os_PacketBuffers	; Packet exists here
	push rcx
	rep movsb			; Copy packet to requested address
	pop rcx

	pop rax
	pop rsi
	pop rdi
	ret

b_net_rx_nodata:
	xor ecx, ecx
	pop rax
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
