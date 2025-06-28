; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Initialize system to start payload
; =============================================================================


; -----------------------------------------------------------------------------
init_sys:
	; Check if there is a payload after the kernel
	cmp qword [0x100000 + KERNELSIZE], 0
	je init_sys_done
	mov byte [os_payload], 0x01	; Set the variable if payload present

	; Copy the payload after the kernel to the proper address
	mov esi, 0x100000 + KERNELSIZE	; Payload starts right after the kernel
	mov edi, 0x1E0000
	mov ecx, 2048
	rep movsq			; Copy 16384 bytes

init_sys_done:
	; Output block to screen (8/8)
	mov ebx, 14
	call os_debug_block

	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
