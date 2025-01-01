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
	ret

b_input_no_key:
	call serial_recv		; Try from the serial port
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_output -- Outputs characters
;  IN:	RSI = message location (non zero-terminated)
;	RCX = number of chars to output
; OUT:	All registers preserved
b_output:
	push rsi			; Message location
	push rcx			; Counter of chars left to output
	push rax			; AL is used for the output function

b_output_nextchar:
	jrcxz b_output_done		; If RCX is 0 then the function is complete
	dec rcx
	lodsb				; Get char from string and store in AL
	call serial_send
	jmp b_output_nextchar

b_output_done:
	pop rax
	pop rcx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
