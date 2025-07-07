; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Network Functions
; =============================================================================


; -----------------------------------------------------------------------------
; b_net_status -- Check if network access is available
;  IN:	RDX = Interface ID
; OUT:	RAX = MAC Address (bits 0-47) if net is enabled, otherwise 0
b_net_status:
	push rsi
	push rcx

	cld
	xor eax, eax
	cmp byte [os_NetEnabled], 0
	je b_net_status_end

	mov ecx, 6

	mov rsi, rdx
	shl esi, 7			; Quick multiply by 128
	add esi, net_table		; Add offset to net_table
	add esi, 8

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
; b_net_config -- Configure an interface
;  IN:	RDX = Interface ID
;	RAX = Base for receive descriptors
; OUT:	Nothing
b_net_config:
	push rsi
	push rdx
	push rcx

	shl edx, 7			; Quick multiply by 128
	add edx, net_table		; Add offset to net_table

	; Call the driver config function
	call [rdx+nt_config]		; Call driver transmit function passing RDX as interface

b_net_config_end:
	pop rcx
	pop rdx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_net_tx -- Transmit a packet via the network
;  IN:	RSI = Memory address of where packet is stored
;	RCX = Length of packet
;	RDX = Interface ID
; OUT:	Nothing. All registers preserved
b_net_tx:
	push rdx
	push rcx
	push rax

	cmp byte [os_NetEnabled], 1	; Check if networking is enabled
	jne b_net_tx_fail

	shl edx, 7			; Quick multiply by 128
	add edx, net_table		; Add offset to net_table

b_net_tx_maxcheck:
	cmp rcx, 1522			; Fail if more than 1522 bytes
	ja b_net_tx_fail

	; Lock the network interface so only one send can happen at a time
	mov rax, rdx
	add rax, nt_lock
	call b_smp_lock

	; Calculate where in physical memory the data should be read from
	xchg rax, rsi
	call os_virt_to_phys
	xchg rax, rsi

	; Call the driver transmit function
	call [rdx+nt_transmit]		; Call driver transmit function passing RDX as interface

	; Unlock the network interface
	mov rax, rdx
	add rax, nt_lock
	call b_smp_unlock

	; Increment interface counters
	inc qword [rdx+nt_tx_packets]
	add qword [rdx+nt_tx_bytes], rcx

b_net_tx_fail:
	pop rax
	pop rcx
	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_net_rx -- Polls the network for received data
;  IN:	RDX = Interface ID
; OUT:	RDI = Memory address of where packet was stored
;	RCX = Length of packet, 0 if no data
;	All other registers preserved
b_net_rx:
	push rdx

	mov cl, byte [os_net_icount]	; Get interface count
	cmp cl, 0
	je b_net_rx_end			; Bail out if there are no valid interfaces
	dec cl				; Interfaces start at 0
	cmp cl, dl
	xor ecx, ecx
	ja b_net_rx_end			; Bail out if it was an invalid interface

	shl edx, 7			; Quick multiply by 128
	add edx, net_table		; Add offset to net_table

	; Call the driver poll function
	call [rdx+nt_poll]		; Call driver poll function passing RDX as interface

	cmp cx, 0			; No data?
	je b_net_rx_end			; If so, don't increment counters

	; Increment interface counters
	inc qword [rdx+nt_rx_packets]
	add qword [rdx+nt_rx_bytes], rcx

b_net_rx_end:
	pop rdx
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
