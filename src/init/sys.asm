; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Initialize system to start payload
; =============================================================================


; -----------------------------------------------------------------------------
init_sys:
	; Copy the payload after the kernel to the proper address
	mov esi, 0x100000 + KERNELSIZE	; Payload starts right after the kernel
	mov edi, 0x1E0000
	mov ecx, 2048
	rep movsq			; Copy 16384 bytes

	; Set the payload to run
bsp_run_payload:
	mov rsi, [os_LocalAPICAddress]	; We can't use b_smp_get_id as no configured stack yet
	xor eax, eax			; Clear Task Priority (bits 7:4) and Task Priority Sub-Class (bits 3:0)
	mov dword [rsi+0x80], eax	; APIC Task Priority Register (TPR)
	mov eax, dword [rsi+0x20]	; APIC ID in upper 8 bits
	shr eax, 24			; Shift to the right and AL now holds the CPU's APIC ID
	mov [os_BSP], al		; Keep a record of the BSP APIC ID
	mov ebx, eax			; Save the APIC ID
	mov rdi, os_SMP			; Clear the entry in the work table
	shl rax, 3			; Quick multiply by 8 to get to proper record
	add rdi, rax
	xor eax, eax
	or al, 1			; Set bit 0 for "present"
	stosq				; Clear the code address
	mov rcx, rbx			; Copy the APIC ID for b_smp_set
	mov rax, 0x1E0000		; Payload was copied here
	call b_smp_set

init_sys_done:
	; Output block to screen (8/8)
	mov ebx, 14
	call os_debug_block
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
