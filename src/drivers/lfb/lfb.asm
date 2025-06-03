; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Linear Frame Buffer Output
; =============================================================================


; -----------------------------------------------------------------------------
; lfb_init -- Initialize the linear frame buffer display
;  IN:	Nothing
; OUT:	Nothing
lfb_init:
	push rdx
	push rcx
	push rbx
	push rax

	; Convert font data to pixel data. The default 12x6 font is 72 pixels per glyph. 288 bytes per.
	mov rdi, os_font
	mov rsi, font_data
	xor ebx, ebx
next_char:
	cmp ebx, 128
	je render_done
	inc ebx
	xor edx, edx			; font_h
next_line:
	cmp edx, font_h
	je next_char
	inc edx
	xor ecx, ecx
	lodsb				; Load a line of font data
next_pixel:
	cmp ecx, font_w			; Font width
	je next_line
	rol al, 1
	bt ax, 0
	jc lit
	push rax
	mov eax, [BG_Color]
	jmp store_pixel
lit:
	push rax
	mov eax, [FG_Color]
store_pixel:
	stosd
	pop rax
	inc ecx
	jmp next_pixel
render_done:

	; Calculate screen parameters
	xor eax, eax
	xor ecx, ecx
	mov ax, [os_screen_x]
	mov cx, [os_screen_y]
	mul ecx
	mov [Screen_Pixels], eax
	mov ecx, 4
	mul ecx
	mov [Screen_Bytes], eax

;	call lfb_clear

	; Calculate display parameters based on font dimensions
	xor eax, eax
	xor edx, edx
	xor ecx, ecx
	mov ax, [os_screen_x]
	mov cl, [font_width]
	div cx				; Divide VideoX by font_width
	mov [Screen_Cols], ax
	xor eax, eax
	xor edx, edx
	xor ecx, ecx
	mov ax, [os_screen_y]
	mov cl, [font_height]
	div cx				; Divide VideoY by font_height
	mov [Screen_Rows], ax

	; Calculate lfb_glyph_bytes
	xor eax, eax
	xor ecx, ecx
	mov al, [font_height]
	mov cl, [font_width]
	mul ecx				; EDX:EAX := EAX * ECX
	shl eax, 2			; Quick multiply by 4
	mov [lfb_glyph_bytes], eax

	; Pixels per row = font_h * [os_screen_x] * 4 * [Screen_Cursor_Row]
	; Todo - [Screen_Cursor_Row] * (font_h * [os_screen_x] * 4)
	; Calculate lfb_bytes_per_row
	xor eax, eax
	xor ecx, ecx
	mov ax, [os_screen_x]
	mov cx, font_h			; Font height
	mul ecx				; EDX:EAX := EAX * ECX
	shl eax, 2			; Quick multiply by 4
	mov [lfb_glyph_bytes_per_row], eax

	xor eax, eax
	mov ax, font_w
	shl eax, 2			; Quick multiply by 4
	mov [lfb_glyph_bytes_per_col], eax

	xor eax, eax
	mov ax, [os_screen_ppsl]	; Use Pixels Per Scan Line in case system aligns video memory
	sub ax, font_w			; Subtract the width of a single glyph
	shl eax, 2			; Quick multiply by 4
	mov [lfb_glyph_next_line], rax

	mov rax, [os_screen_lfb]
	mov [LastLine], rax

	; Overwrite the kernel b_output function so output goes to the screen instead of the serial port
	mov rax, lfb_output_chars
	mov [0x100018], rax

	pop rax
	pop rbx
	pop rcx
	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; lfb_inc_cursor -- Increment the cursor by one
;  IN:	Nothing
; OUT:	All registers preserved
lfb_inc_cursor:
	push rax

	inc word [Screen_Cursor_Col]	; Increment the current cursor column
	mov ax, [Screen_Cursor_Col]
	cmp ax, [Screen_Cols]		; Compare it to the # of columns for the screen
	jne lfb_inc_cursor_done		; If not equal we are done
	mov word [Screen_Cursor_Col], 0	; Reset column to 0
	inc word [Screen_Cursor_Row]	; Increment the current cursor row
	call lfb_draw_line
	mov ax, [Screen_Cursor_Row]
	cmp ax, [Screen_Rows]		; Compare it to the # of rows for the screen
	jne lfb_inc_cursor_done		; If not equal we are done
	mov word [Screen_Cursor_Row], 0	; Wrap around
lfb_inc_cursor_done:
	pop rax
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; lfb_dec_cursor -- Decrement the cursor by one
;  IN:	Nothing
; OUT:	All registers preserved
lfb_dec_cursor:
	push rax

	cmp word [Screen_Cursor_Col], 0	; Compare the current cursor column to 0
	jne lfb_dec_cursor_done		; If not equal we are done
	dec word [Screen_Cursor_Row]	; Otherwise decrement the row
	mov ax, [Screen_Cols]		; Get the total columns and save it as the current
	mov word [Screen_Cursor_Col], ax

lfb_dec_cursor_done:
	dec word [Screen_Cursor_Col]	; Decrement the cursor as usual

	pop rax
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; lfb_output_chars -- Output text to LFB
;  IN:	RSI = message location (an ASCII string, not zero-terminated)
;	RCX = number of chars to print
; OUT:	All registers preserved
lfb_output_chars:
	push rsi
	push rcx
	push rax

lfb_output_chars_nextchar:
	cmp rcx, 0
	jz lfb_output_chars_done
	dec rcx
	lodsb				; Get char from string and store in AL
	cmp al, 0x20
	jae lfb_output_chars_nextchar_output
	cmp al, 0x0A			; LF - Check if there was a newline (aka line feed) character in the string
	je lfb_output_chars_newline	; If so then we print a new line
	cmp al, 0x0D			; CR - Check if there was a carriage return character in the string
	je lfb_output_chars_cr		; If so reset to column 0
	cmp al, 0x0E			; Backspace
	je lfb_output_backspace
	cmp al, 0x09
	je lfb_output_chars_tab
	; Check for special characters
	cmp al, 0x01			; Clear Screen
	je lfb_output_cls
	cmp al, 0x02			; Increment Cursor
	je lfb_output_inc_cursor
	cmp al, 0x03			; Decrement Cursor
	je lfb_output_dec_cursor
lfb_output_chars_nextchar_output:
	call lfb_output_char
	jmp lfb_output_chars_nextchar

lfb_output_chars_newline:
	mov al, [rsi]
	cmp al, 0x0A
	je lfb_output_chars_newline_skip_LF
	call lfb_output_newline
	jmp lfb_output_chars_nextchar

lfb_output_chars_cr:
	mov al, [rsi]			; Check the next character
	cmp al, 0x0A			; Is it a newline?
	je lfb_output_chars_newline	; If so, display a newline and ignore the carriage return
	push rcx
	xor eax, eax
	xor ecx, ecx
	mov [Screen_Cursor_Col], ax
	mov cx, [Screen_Cols]
	mov al, ' '
lfb_output_chars_cr_clearline:
	call lfb_output_char
	dec cx
	jnz lfb_output_chars_cr_clearline
	dec word [Screen_Cursor_Row]
	xor eax, eax
	mov [Screen_Cursor_Col], ax
	pop rcx
	jmp lfb_output_chars_nextchar

lfb_output_backspace:
	call lfb_dec_cursor		; Decrement the cursor
	mov al, ' '			; 0x20 is the character for a space
	call lfb_output_char		; Write over the last typed character with the space
	call lfb_dec_cursor		; Decrement the cursor again
	jmp lfb_output_chars_nextchar

lfb_output_chars_newline_skip_LF:
	test rcx, rcx
	jz lfb_output_chars_newline_skip_LF_nosub
	dec rcx

lfb_output_chars_newline_skip_LF_nosub:
	inc rsi
	call lfb_output_newline
	jmp lfb_output_chars_nextchar

lfb_output_chars_tab:
	push rcx
	mov ax, [Screen_Cursor_Col]	; Grab the current cursor X value (ex 7)
	mov cx, ax
	add ax, 8			; Add 8 (ex 15)
	shr ax, 3			; Clear lowest 3 bits (ex 8)
	shl ax, 3			; Bug? 'xor al, 7' doesn't work...
	sub ax, cx			; (ex 8 - 7 = 1)
	mov cx, ax
	mov al, ' '

lfb_output_chars_tab_next:
	call lfb_output_char
	dec cx
	jnz lfb_output_chars_tab_next
	pop rcx
	jmp lfb_output_chars_nextchar

lfb_output_cls:
	call lfb_clear
	call lfb_draw_line
	jmp lfb_output_chars_nextchar

lfb_output_inc_cursor:
	call lfb_inc_cursor
	jmp lfb_output_chars_nextchar

lfb_output_dec_cursor:
	call lfb_dec_cursor
	jmp lfb_output_chars_nextchar

lfb_output_chars_done:
	pop rax
	pop rcx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; lfb_output_char -- Displays a char
;  IN:	AL  = char to display
; OUT:	All registers preserved
lfb_output_char:
	call lfb_glyph
	call lfb_inc_cursor
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; lfb_output_newline -- Reset cursor to start of next line and wrap if needed
;  IN:	Nothing
; OUT:	All registers preserved
lfb_output_newline:
	push rax

	mov word [Screen_Cursor_Col], 0	; Reset column to 0
	mov ax, [Screen_Rows]		; Grab max rows on screen
	dec ax				; and subtract 1
	cmp ax, [Screen_Cursor_Row]	; Is the cursor already on the bottom row?
	je lfb_output_newline_wrap	; If so, then wrap
	inc word [Screen_Cursor_Row]	; If not, increment the cursor to next row
	jmp lfb_output_newline_done

lfb_output_newline_wrap:
	mov word [Screen_Cursor_Row], 0

lfb_output_newline_done:
	call lfb_draw_line
	pop rax
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; lfb_glyph -- Put a glyph on the screen at the cursor location
;  IN:	AL  = char to display
; OUT:	All registers preserved
lfb_glyph:
	push rdi
	push rsi
	push rdx
	push rcx
	push rax

	; Filter out characters that can't be displayed
	and eax, 0x000000FF		; Only keep AL
	cmp al, 0x20
	jb hidden
	cmp al, 127
	ja hidden
	sub rax, 0x20
	jmp load_char
hidden:
	mov al, 0
load_char:

	push rax			; Save the character to display

	; Calculate where to put glyph in the Linear Frame Buffer
	mov rdi, [os_screen_lfb]

	; Calculate offset for row into Linear Frame Buffer
	xor ecx, ecx
	mov eax, [lfb_glyph_bytes_per_row]
	mov cx, [Screen_Cursor_Row]
	mul ecx				; EDX:EAX := EAX * ECX
	add rdi, rax

	; Calculate offset for column into Linear Frame Buffer
	xor ecx, ecx
	mov eax, [lfb_glyph_bytes_per_col]
	mov cx, [Screen_Cursor_Col]
	mul ecx				; EDX:EAX := EAX * ECX
	add rdi, rax

	pop rax				; Restore the character to display

	; Copy glyph data to Linear Frame Buffer
	mov rsi, os_font		; Font pixel data
	mov ecx, [lfb_glyph_bytes]	; Bytes per glyph
	mul ecx				; EDX:EAX := EAX * ECX
	xor edx, edx			; Counter for font height
	add rsi, rax			; RSI points to start of glyph
	mov rax, [lfb_glyph_next_line]
lfb_glyph_next:
	mov ecx, font_w
	rep movsd
	add rdi, rax			; Skip to next line in Linear Frame Buffer
	inc edx
	cmp edx, font_h
	jne lfb_glyph_next

lfb_glyph_done:
	pop rax
	pop rcx
	pop rdx
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; lfb_pixel -- Put a pixel on the screen
;  IN:	EBX = Packed X & Y coordinates (YYYYXXXX)
;	EAX = Pixel Details (AARRGGBB)
; OUT:	All registers preserved
lfb_pixel:
	push rdi
	push rdx
	push rcx
	push rbx
	push rax

	; Calculate offset in video memory and store pixel
	push rax			; Save the pixel details
	mov rax, rbx
	shr eax, 16			; Isolate Y co-ordinate
	xor ecx, ecx
	mov cx, [os_screen_ppsl]
	mul ecx				; Multiply Y by VideoPPSL
	and ebx, 0x0000FFFF		; Isolate X co-ordinate
	add eax, ebx			; Add X
	mov rbx, rax			; Save the offset to RBX
	mov rdi, [os_screen_lfb]	; Store the pixel to video memory
	pop rax				; Restore pixel details
	shl ebx, 2			; Quickly multiply by 4
	add rdi, rbx			; Add offset in video memory
	stosd				; Output pixel to video memory

	pop rax
	pop rbx
	pop rcx
	pop rdx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; lfb_clear -- Clear the Linear Frame Buffer
;  IN:	Nothing
; OUT:	All registers preserved
lfb_clear:
	push rdi
	push rcx
	push rax

	; Set cursor to top left corner
	mov word [Screen_Cursor_Col], 0
	mov word [Screen_Cursor_Row], 0

	; Fill the Linear Frame Buffer with the background colour
	mov rdi, [os_screen_lfb]
	mov eax, [BG_Color]
	mov ecx, [Screen_Bytes]
	shr ecx, 2			; Quick divide by 4
	rep stosd

	pop rax
	pop rcx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; lfb_draw_line
lfb_draw_line:
	push rdi
	push rdx
	push rcx
	push rax

; Clear the previously drawn line
	mov rdi, [LastLine]
	mov cx, [os_screen_ppsl]
	mov eax, [BG_Color]
	rep stosd

; Display a line under the current cursor row
	mov rdi, [os_screen_lfb]
	xor ecx, ecx
	xor eax, eax
	mov ax, [Screen_Cursor_Row]
	add ax, 1
	mov cx, font_h * 4		; Font height
	mul cx
	mov cx, [os_screen_ppsl]
	mul ecx				; Multiply Y by os_screen_ppsl
	add rdi, rax
	mov [LastLine], rdi
	xor ecx, ecx
	mov cx, [os_screen_ppsl]
	mov eax, [Line_Color]
	rep stosd

; Clear the next row of text
	mov ax, [Screen_Cursor_Row]	; Get the current cursor row
	inc ax				; Inc by 1 as it is 0-based
	cmp ax, [Screen_Rows]		; Compare it to the # of rows for the screen
	jne lfb_draw_line_skip
	mov rdi, [os_screen_lfb]	; Roll RDI back to the start of video memory
lfb_draw_line_skip:
	xor eax, eax
	mov ax, [os_screen_ppsl]
	mov ecx, font_h
	mul ecx
	mov ecx, eax
	mov eax, [BG_Color]
	rep stosd

	pop rax
	pop rcx
	pop rdx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; Font data - Only 1 font may be used
align 16
;%include 'drivers/lfb/fonts/smol.fnt' ; 8x4
%include 'drivers/lfb/fonts/baremetal.fnt' ; 12x6
;%include 'drivers/lfb/fonts/departuremono.fnt' ; 14x7
;%include 'drivers/lfb/fonts/ibm.fnt' ; 16x8


; Variables
align 16

LastLine:		dq 0
lfb_glyph_next_line:	dq 0
FG_Color:		dd 0x00FFFFFF	; White
BG_Color:		dd 0x00404040	; Dark grey
Line_Color:		dd 0x00F7CA54	; Return Infinity Yellow/Orange
Screen_Pixels:		dd 0
Screen_Bytes:		dd 0
lfb_glyph_bytes:	dd 0
lfb_glyph_bytes_per_row:	dd 0
lfb_glyph_bytes_per_col:	dd 0
Screen_Rows:		dw 0
Screen_Cols:		dw 0
Screen_Cursor_Row:	dw 0
Screen_Cursor_Col:	dw 0


; =============================================================================
; EOF
