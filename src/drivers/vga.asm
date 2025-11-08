; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; VGA Text mode functions
; =============================================================================


; -----------------------------------------------------------------------------
; vga_init -- Initialize VGA text output
;  IN:	Nothing
; OUT:	Nothing
;	All other registers preserved
vga_init:
	mov word [vga_Rows], 25
	mov word [vga_Cols], 80
	mov word [vga_Cursor_Row], 0
	mov word [vga_Cursor_Col], 0
	call vga_clear_screen

; Set color palette
	xor eax, eax
	mov dx, 0x03C8			; DAC Address Write Mode Register
	out dx, al
	mov dx, 0x03C9			; DAC Data Register
	mov rbx, 16			; 16 lines
nextlineq:
	mov rcx, 16			; 16 colors
	mov rsi, palette
nexttritone:
	lodsb
	out dx, al
	lodsb
	out dx, al
	lodsb
	out dx, al
	dec rcx
	test rcx, rcx
	jnz nexttritone
	dec rbx
	jnz nextlineq			; Set the next 16 colors to the same

	mov eax, 0x14			; Fix for color 6
	mov dx, 0x03C8			; DAC Address Write Mode Register
	out dx, al
	mov dx, 0x03C9			; DAC Data Register
	mov rsi, palette
	add rsi, 18
	lodsb
	out dx, al
	lodsb
	out dx, al
	lodsb
	out dx, al

	mov rax, vga_output_chars
	mov [0x100018], rax

	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; vga_clear_screen -- Clear the screen
;  IN:	Nothing
; OUT:	All registers preserved
vga_clear_screen:
	push rdi
	push rcx
	push rax
	pushfq

	; Set cursor to top left corner
	mov word [vga_Cursor_Row], 0
	mov word [vga_Cursor_Col], 0

	cld				; Clear the direction flag as we want to increment through memory

	xor ecx, ecx
	mov ax, 0x8F20			; 0x8F for gray background/bright white foreground, 0x20 for space (black) character
	mov edi, 0xB8000
	mov ecx, 2000			; 80 x 25
	rep stosw			; Clear the screen. Store word in AX to RDI, RCX times

	popfq
	pop rax
	pop rcx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_inc_cursor -- Increment the cursor by one, scroll if needed
;  IN:	Nothing
; OUT:	All registers preserved
vga_inc_cursor:
	push rax

	inc word [vga_Cursor_Col]	; Increment the current cursor column
	mov ax, [vga_Cursor_Col]
	cmp ax, [vga_Cols]		; Compare it to the # of columns for the screen
	jne vga_inc_cursor_done		; If not equal we are done
	mov word [vga_Cursor_Col], 0	; Reset column to 0
	inc word [vga_Cursor_Row]	; Increment the current cursor row
	call vga_draw_line
	mov ax, [vga_Cursor_Row]
	cmp ax, [vga_Rows]		; Compare it to the # of rows for the screen
	jne vga_inc_cursor_done		; If not equal we are done
	mov word [vga_Cursor_Row], 0	; Wrap around

vga_inc_cursor_done:
	call vga_update_cursor

	pop rax
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_dec_cursor -- Decrement the cursor by one
;  IN:	Nothing
; OUT:	All registers preserved
vga_dec_cursor:
	push rax

	cmp word [vga_Cursor_Col], 0	; Compare the current cursor column to 0
	jne vga_dec_cursor_done		; If not equal we are done
	dec word [vga_Cursor_Row]	; Otherwise decrement the row
	mov ax, [vga_Cols]		; Get the total columns and save it as the current
	mov word [vga_Cursor_Col], ax

vga_dec_cursor_done:
	dec word [vga_Cursor_Col]	; Decrement the cursor as usual
	call vga_update_cursor

	pop rax
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; vga_update_cursor -- Update the cursor
;  IN:	Nothing
; OUT:	All registers preserved
vga_update_cursor:
	; Check if cursor is enabled
	cmp byte [vga_cursor_on], 1	; 1 means enabled
	jne vga_update_cursor_skip	; If not, skip entire function

	push rdx
	push rcx
	push rbx
	push rax

	; Calculate offset (vga_Cursor_Row * 80 + vga_Cursor_Col)
	xor eax, eax
	mov ax, [vga_Cursor_Row]
	mov ecx, 80
	mul ecx
	mov ebx, eax
	xor eax, eax
	mov ax, [vga_Cursor_Col]
	add ebx, eax

	; Update VGA hardware cursor location
	mov dx, 0x03D4
	mov al, 0x0F
	out dx, al			; 0x03D4
	inc dx
	mov ax, bx
	out dx, al			; 0x03D5
	shr bx, 8
	dec dx
	mov al, 0x0E
	out dx, al			; 0x03D4
	inc dx
	mov ax, bx
	out dx, al			; 0x03D5

	pop rax
	pop rbx
	pop rcx
	pop rdx

vga_update_cursor_skip:
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
vga_disable_cursor:
	push rdx
	push rax

	mov dx, 0x3D4
	mov al, 0x0A
	out dx, al
	inc dx
	mov al, 0x20
	out dx, al

	pop rax
	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
vga_enable_cursor:
	push rdx
	push rax

	mov dx, 0x3D4
	mov al, 0x0A
	out dx, al
	inc dx
	mov al, 0x00
	out dx, al

	pop rax
	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; vga_output_newline -- Reset cursor to start of next line and wrap if needed
;  IN:	Nothing
; OUT:	All registers preserved
vga_output_newline:
	push rax

	mov word [vga_Cursor_Col], 0	; Reset column to 0
	mov ax, [vga_Rows]		; Grab max rows on screen
	dec ax				; and subtract 1
	cmp ax, [vga_Cursor_Row]	; Is the cursor already on the bottom row?
	je vga_output_newline_wrap	; If so, then wrap
	inc word [vga_Cursor_Row]	; If not, increment the cursor to next row
	jmp vga_output_newline_done

vga_output_newline_wrap:
	mov word [vga_Cursor_Row], 0

vga_output_newline_done:
	call vga_draw_line
	pop rax
	ret
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; vga_output_char -- Displays a char
;  IN:	AL  = char to display
; OUT:	All registers preserved
vga_output_char:
	push rdi
	push rdx
	push rcx
	push rbx
	push rax

	push rax
	mov ax, [vga_Cursor_Row]
	and rax, 0x000000000000FFFF	; only keep the low 16 bits
	mov cl, 80			; 80 columns per row
	mul cl				; AX = AL * CL
	mov bx, [vga_Cursor_Col]
	add ax, bx
	shl ax, 1			; multiply by 2
	mov rbx, rax			; Save the row/col offset
	pop rax
	mov rdi, 0xb8000
	add rdi, rbx
	stosb				; Write the character and attribute to screen

vga_output_char_done:
	call vga_inc_cursor

	pop rax
	pop rbx
	pop rcx
	pop rdx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; vga_output_chars -- Displays text
;  IN:	RSI = message location (an ASCII string, not zero-terminated)
;	RCX = number of chars to print
; OUT:	All registers preserved
vga_output_chars:
	push rdi
	push rsi
	push rcx
	push rax

	cld				; Clear the direction flag.. we want to increment through the string

vga_output_chars_nextchar:
	cmp rcx, 0
	jz vga_output_chars_done
	dec rcx
	lodsb				; Get char from string and store in AL
	cmp al, 13			; Check if there was a newline character in the string
	je vga_output_chars_newline	; If so then we print a new line
	cmp al, 10			; Check if there was a newline character in the string
	je vga_output_chars_newline	; If so then we print a new line
	cmp al, 9
	je vga_output_chars_tab
	; Check for special characters
	cmp al, 0x01			; Clear Screen
	je vga_output_cls
	cmp al, 0x02			; Increment Cursor
	je vga_output_inc_cursor
	cmp al, 0x03			; Decrement Cursor
	je vga_output_dec_cursor
	call vga_output_char
	jmp vga_output_chars_nextchar

vga_output_cls:
	call vga_clear_screen
	call vga_draw_line
	jmp vga_output_chars_nextchar

vga_output_inc_cursor:
	call vga_inc_cursor
	jmp vga_output_chars_nextchar

vga_output_dec_cursor:
	call vga_dec_cursor		; Decrement the cursor
	mov al, ' '			; 0x20 is the character for a space
	call vga_output_char		; Write over the last typed character with the space
	call vga_dec_cursor		; Decrement the cursor again
	jmp vga_output_chars_nextchar

vga_output_chars_newline:
	mov al, [rsi]
	cmp al, 10
	je vga_output_chars_newline_skip_LF
	call vga_output_newline
	jmp vga_output_chars_nextchar

vga_output_chars_newline_skip_LF:
	test rcx, rcx
	jz vga_output_chars_newline_skip_LF_nosub
	dec rcx
vga_output_chars_newline_skip_LF_nosub:
	inc rsi
	call vga_output_newline
	jmp vga_output_chars_nextchar

vga_output_chars_tab:
	push rcx
	mov ax, [vga_Cursor_Col]	; Grab the current cursor X value (ex 7)
	mov cx, ax
	add ax, 8			; Add 8 (ex 15)
	shr ax, 3			; Clear lowest 3 bits (ex 8)
	shl ax, 3			; Bug? 'xor al, 7' doesn't work...
	sub ax, cx			; (ex 8 - 7 = 1)
	mov cx, ax
	mov al, ' '
vga_output_chars_tab_next:
	call vga_output_char
	dec cx
	jnz vga_output_chars_tab_next
	pop rcx
	jmp vga_output_chars_nextchar

vga_output_chars_done:
	pop rax
	pop rcx
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; vga_draw_line - Draw the line for the rolling output
vga_draw_line:
	push rdi
	push rdx
	push rcx
	push rax

	; Clear the old line
	xor eax, eax
	mov ax, [vga_Cursor_Row]	; Gather the current cursor row
	cmp ax, [vga_Rows]
	jne vga_draw_line_clear
	mov ax, 0
vga_draw_line_clear:
	mov ecx, 160
	mul ecx
	mov ecx, 80
	mov edi, 0xB8000
	add edi, eax
	mov ax, 0x8F20			; Gray/White, Upper half block
	rep stosw

	; Output the new line
	xor eax, eax
	mov ax, [vga_Cursor_Row]	; Gather the current cursor row
	add ax, 1			; Increment it
	cmp ax, [vga_Rows]
	jne vga_draw_line_continue
	mov ax, 0
vga_draw_line_continue:
	mov ecx, 160
	mul ecx
	mov ecx, 80
	mov edi, 0xB8000
	add edi, eax
	mov ax, 0x84DF			; Gray/Orange, Upper half block
	rep stosw

	pop rax
	pop rcx
	pop rdx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; Variables
vga_Rows:		dw 0
vga_Cols:		dw 0
vga_Cursor_Row:		dw 0
vga_Cursor_Col:		dw 0
vga_cursor_on:		db 1

palette:		; These colors are in RGB format. Each color byte is actually 6 bits (0x00 - 0x3F)
db 0x00, 0x00, 0x00	;  0 Black
db 0x33, 0x00, 0x00	;  1 Red
db 0x0F, 0x26, 0x01	;  2 Green
db 0x0D, 0x19, 0x29	;  3 Blue
db 0x31, 0x28, 0x00	;  4 Orange
db 0x1D, 0x14, 0x1E	;  5 Purple
db 0x01, 0x26, 0x26	;  6 Teal
db 0x2A, 0x2A, 0x2A	;  7 Light Gray
db 0x15, 0x15, 0x15	;  8 Dark Gray
db 0x3B, 0x0A, 0x0A	;  9 Bright Red
db 0x22, 0x38, 0x0D	; 10 Bright Green
db 0x1C, 0x27, 0x33	; 11 Bright Blue
db 0x3F, 0x3A, 0x13	; 12 Yellow
db 0x2B, 0x1F, 0x2A	; 13 Bright Purple
db 0x0D, 0x38, 0x38	; 14 Bright Teal
db 0x3F, 0x3F, 0x3F	; 15 White


; =============================================================================
; EOF