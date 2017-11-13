; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2017 Return Infinity -- see LICENSE.TXT
;
; Output Functions
; =============================================================================


; -----------------------------------------------------------------------------
; b_output -- Outputs a string
;  IN:	RSI = message location (zero-terminated string)
; OUT:	All registers preserved
b_output:
	push rdi
	push rcx
	push rax
	pushf

	xor ecx, ecx			; 0 terminator for scasb
	xor eax, eax
	mov rdi, rsi
	not rcx
	cld
	repne scasb			; compare byte at RDI to value in AL
	not rcx
	dec rcx

	call b_output_chars

	popf
	pop rax
	pop rcx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_output_chars -- Outputs characters
;  IN:	RSI = message location (non zero-terminated)
;	RCX = number of chars to output
; OUT:	All registers preserved
b_output_chars:
	push rdi
	push rsi
	push rdx
	push rcx
	push rax

	cld				; Clear the direction flag.. we want to increment through the string
	mov dx, 0x03F8			; Address of first serial port

b_output_chars_nextchar:
	jrcxz b_output_chars_done
	dec rcx
	lodsb				; Get char from string and store in AL
	out dx, al			; Send the char to the serial port
	jmp b_output_chars_nextchar

b_output_chars_done:
	pop rax
	pop rcx
	pop rdx
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
