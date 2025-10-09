; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Input/Output Functions
; =============================================================================


; -----------------------------------------------------------------------------
; b_input -- Scans keyboard for input
;  IN:	Nothing
; OUT:	AL = 0 if no key pressed, otherwise ASCII code, other regs preserved
;	All other registers preserved
b_input:
	mov al, [key]
	test al, al
	jz b_input_no_key
	mov byte [key], 0x00		; clear the variable as the keystroke is in AL now
b_input_no_key:
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_output -- Outputs characters via kernel call
;  IN:	RSI = Memory address of message (non zero-terminated)
;	RCX = number of chars to output
; OUT:	All registers preserved
b_output:
	call [0x00100018]		; Call kernel function in table
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_output_serial -- Outputs characters via serial
;  IN:	RSI = Memory address of message (non zero-terminated)
;	RCX = number of chars to output
; OUT:	All registers preserved
b_output_serial:
	push rsi
	push rcx
	push rax

b_output_serial_next:
	lodsb				; Load a byte from the string into AL
	call serial_send		; Output it via serial
	dec cx				; Decrement the counter
	jnz b_output_serial_next	; Loop if counter isn't zero

	pop rax
	pop rcx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
