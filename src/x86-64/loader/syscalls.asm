; =============================================================================
; Pure64 -- a 64-bit OS loader written in Assembly for x86-64 systems
; Copyright (C) 2008-2016 Return Infinity -- see LICENSE.TXT
;
; System Calls
; =============================================================================


; -----------------------------------------------------------------------------
; os_move_cursor -- Moves the virtual cursor in text mode
;  IN:	AH, AL = row, column
; OUT:	Nothing. All registers preserved
os_move_cursor:
	push rcx
	push rbx
	push rax

	xor ebx, ebx
	movzx ebx, ah
	mov [screen_cursor_x], bl
	mov [screen_cursor_y], al

	; Calculate the new offset
	movzx eax, al	; only keep the low 8 bits
	movzx ecx, al
	shl eax, 7	; al*128
	shl ecx, 5	; al*32				; 
	add eax, ecx			; AX = (AL* 80 + BL)*2
	lea eax, [rax+rbx*2]		; =160*AL+2*BL

	add eax, 0xB8000
	mov [screen_cursor_offset], rax

	pop rax
	pop rbx
	pop rcx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_print_newline -- Reset cursor to start of next line and scroll if needed
;  IN:	Nothing
; OUT:	Nothing, all registers perserved
os_print_newline:
	push rax
	push rbx
	xor ebx, ebx
					; Set the cursor x value to 0
	movzx eax, byte [screen_cursor_y]	; Grab the cursor y value
	add eax, 1			
	cmp eax, 25
	cmove eax, ebx			; If we have reached the end then wrap back to the front

os_print_newline_done:
	call os_move_cursor		; update the cursor
	
	pop rbx
	pop rax
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_print_string -- Displays text
;  IN:	RSI = message location (zero-terminated string)
; OUT:	Nothing, all registers perserved
os_print_string:
	push rsi
	push rax

	cld				; Clear the direction flag.. we want to increment through the string

os_print_string_nextchar:
	lodsb				; Get char from string and store in AL
	cmp al, 0			; Strings are Zero terminated.
	je os_print_string_done		; If char is Zero then it is the end of the string

	cmp al, 13			; Check if there was a newline character in the string
	je os_print_string_newline	; If so then we print a new line

	call os_print_char

	jmp os_print_string_nextchar

os_print_string_newline:
	call os_print_newline
	jmp os_print_string_nextchar

os_print_string_done:
	pop rax
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_print_char -- Displays a char
;  IN:	AL = char to display
; OUT:	Nothing. All registers preserved
os_print_char:
	push rdi

	mov rdi, [screen_cursor_offset]
	stosb
	add rdi, 2
	mov [screen_cursor_offset], rdi	; Add 2 (1 byte for char and 1 byte for attribute)

	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_print_char_hex -- Displays a char in hex mode
;  IN:	AL = char to display
; OUT:	Nothing. All registers preserved
os_print_char_hex:
	push rbx
	push rax

	mov ebx, hextable

	push rax			; save rax for the next part
	shr al, 4			; we want to work on the high part so shift right by 4 bits
	xlatb
	call os_print_char

	pop rax
	and al, 0x0f			; we want to work on the low part so clear the high part
	xlatb
	call os_print_char

	pop rax
	pop rbx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_debug_dump_(rax|eax|ax|al) -- Dump content of RAX, EAX, AX, or AL to the screen in hex format
;  IN:	RAX = content to dump
; OUT:	Nothing, all registers preserved
os_debug_dump_rax:
	ror rax, 56
	call os_print_char_hex
	rol rax, 8
	call os_print_char_hex
	rol rax, 8
	call os_print_char_hex
	rol rax, 8
	call os_print_char_hex
	rol rax, 32
os_debug_dump_eax:
	ror rax, 24
	call os_print_char_hex
	rol rax, 8
	call os_print_char_hex
	rol rax, 16
os_debug_dump_ax:
	ror rax, 8
	call os_print_char_hex
	rol rax, 8
os_debug_dump_al:
	call os_print_char_hex
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_dump_regs -- Dump the values on the registers to the screen (For debug purposes)
; IN/OUT: Nothing
os_dump_regs:
	push r15
	push r14
	push r13
	push r12
	push r11
	push r10
	push r9
	push r8
	push rsp
	push rbp
	push rdi
	push rsi
	push rdx
	push rcx
	push rbx
	push rax

	mov byte [os_dump_reg_stage], 0x00	; Reset the stage to 0 since we are starting
	mov rcx, rsp
	call os_print_newline

os_dump_regs_again:
	mov esi, os_dump_reg_string00
	movzx eax, byte [os_dump_reg_stage]
	lea eax,[rax+rax*4]			; each string is 5 bytes
	add rsi, rax
	call os_print_string			; Print the register name

	mov rax, [rcx]
	add rcx, 8
	call os_debug_dump_rax

	add byte [os_dump_reg_stage], 1
	cmp byte [os_dump_reg_stage], 0x10
	jne os_dump_regs_again

	pop rax
	pop rbx
	pop rcx
	pop rdx
	pop rsi
	pop rdi
	pop rbp
	pop rsp
	pop r8
	pop r9
	pop r10
	pop r11
	pop r12
	pop r13
	pop r14
	pop r15

ret

os_dump_reg_string00: db '  A:', 0
os_dump_reg_string01: db '  B:', 0
os_dump_reg_string02: db '  C:', 0
os_dump_reg_string03: db '  D:', 0
os_dump_reg_string04: db ' SI:', 0
os_dump_reg_string05: db ' DI:', 0
os_dump_reg_string06: db ' BP:', 0
os_dump_reg_string07: db ' SP:', 0
os_dump_reg_string08: db '  8:', 0
os_dump_reg_string09: db '  9:', 0
os_dump_reg_string0A: db ' 10:', 0
os_dump_reg_string0B: db ' 11:', 0
os_dump_reg_string0C: db ' 12:', 0
os_dump_reg_string0D: db ' 13:', 0
os_dump_reg_string0E: db ' 14:', 0
os_dump_reg_string0F: db ' 15:', 0
os_dump_reg_stage: db 0x00
; -----------------------------------------------------------------------------



; -----------------------------------------------------------------------------
; os_dump_mem -- Dump some memory content to the screen (For debug purposes)
; IN: RSI = memory to dump (512bytes)
;OUT:
os_dump_mem:
	push rdx
	push rcx
	push rbx
	push rax

	push rsi

	mov ecx, 512
dumpit:
	movzx eax, [rsi]
	add rsi, 1
	call os_print_char_hex
	dec ecx
	jnz dumpit

	pop rsi

;	call os_print_newline

	pop rax
	pop rbx
	pop rcx
	pop rdx
ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_int_to_string -- Convert a binary interger into an string string
;  IN:	RAX = binary integer
;	RDI = location to store string
; OUT:	RDI = pointer to end of string
;	All other registers preserved
; Min return value is 0 and max return value is 18446744073709551615 so your
; string needs to be able to store at least 21 characters (20 for the number
; and 1 for the string terminator).
; Adapted from http://www.cs.usfca.edu/~cruse/cs210s09/rax2uint.s
os_int_to_string:
	push rdx
	push rcx
	push rbx
	push rax

	mov ebx, 10				; base of the decimal system
	xor ecx, ecx				; number of digits generated
os_int_to_string_next_divide:
	xor edx, edx				; RAX extended to (RDX,RAX)
	div ebx					; divide by the number-base
	push edx				; save remainder on the stack
	inc ecx					; and count this remainder
	test eax, eax				; was the quotient zero?
	jne os_int_to_string_next_divide	; no, do another division
os_int_to_string_next_digit:
	pop rdx					; else pop recent remainder
	add dl, '0'				; and convert to a numeral
	mov [rdi], dl				; store to memory-buffer
	inc edi
	loop os_int_to_string_next_digit	; again for other remainders
	xor eax, eax
	stosb					; Store the null terminator at the end of the string

	pop rax
	pop rbx
	pop rcx
	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; create_gate
; rax = address of handler
; rdi = gate # to configure
create_gate:
	push rdi
	push rax

	shl rdi, 4			; quickly multiply rdi by 16
	stosw				; store the low word (15..0)
	shr rax, 16
	add rdi, 4			; skip the gate marker
	stosw				; store the high word (31..16)
	shr rax, 16
	stosd				; store the high dword (63..32)

	pop rax
	pop rdi
ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
