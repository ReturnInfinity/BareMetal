; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2015 Return Infinity -- see LICENSE.TXT
;
; Screen Output Functions
; =============================================================================


; -----------------------------------------------------------------------------
; os_inc_cursor -- Increment the cursor by one, scroll if needed
;  IN:	Nothing
; OUT:	All registers preserved
os_inc_cursor:
	push rax

	add word [os_Screen_Cursor_Col], 1
	mov ax, [os_Screen_Cursor_Col]
	cmp ax, [os_Screen_Cols]
	jne os_inc_cursor_done
	mov word [os_Screen_Cursor_Col], 0
	add word [os_Screen_Cursor_Row], 1
	mov ax, [os_Screen_Cursor_Row]
	cmp ax, [os_Screen_Rows]
	jne os_inc_cursor_done
	call os_screen_scroll
	sub word [os_Screen_Cursor_Row], 1

os_inc_cursor_done:
	pop rax
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_dec_cursor -- Decrement the cursor by one
;  IN:	Nothing
; OUT:	All registers preserved
os_dec_cursor:
	push rax

	cmp word [os_Screen_Cursor_Col], 0
	jne os_dec_cursor_done
	sub word [os_Screen_Cursor_Row], 1
	mov ax, [os_Screen_Cols]
	mov word [os_Screen_Cursor_Col], ax

os_dec_cursor_done:
	sub word [os_Screen_Cursor_Col], 1

	pop rax
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_print_newline -- Reset cursor to start of next line and scroll if needed
;  IN:	Nothing
; OUT:	All registers preserved
os_print_newline:
	push rax

	mov word [os_Screen_Cursor_Col], 0	; Reset column to 0
	mov ax, [os_Screen_Rows]		; Grab max rows on screen
	sub ax, 1				; and subtract 1
	cmp ax, [os_Screen_Cursor_Row]		; Is the cursor already on the bottom row?
	je os_print_newline_scroll		; If so, then scroll
	add word [os_Screen_Cursor_Row], 1	; If not, increment the cursor to next row
	jmp os_print_newline_done

os_print_newline_scroll:
	call os_screen_scroll

os_print_newline_done:
	pop rax
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_output -- Displays text
;  IN:	RSI = message location (zero-terminated string)
; OUT:	All registers preserved
os_output:
	push rdi
	push rcx
	push rax

	xor ecx, ecx
	xor eax, eax
	mov rdi, rsi
	not rcx
	cld
	repne scasb			; compare byte at RDI to value in AL
	not rcx
	dec rcx

	call os_output_chars

	pop rax
	pop rcx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_output_char -- Displays a char
;  IN:	AL  = char to display
; OUT:	All registers preserved
os_output_char:
	push rdi
	push rdx
	push rcx
	push rbx
	push rax

	mov ah, 0x07			; Store the attribute into AH so STOSW can be used later on

	push rax
	mov ax, [os_Screen_Cursor_Row]
	and rax, 0x000000000000FFFF	; only keep the low 16 bits
	mov cl, 80			; 80 columns per row
	mul cl				; AX = AL * CL
	mov bx, [os_Screen_Cursor_Col]
	add ax, bx
	shl ax, 1			; multiply by 2
	mov rbx, rax			; Save the row/col offset
	mov rdi, os_screen		; Address of the screen buffer
	add rdi, rax
	pop rax
	stosw				; Write the character and attribute to screen buffer
	mov rdi, 0xb8000
	add rdi, rbx
	stosw				; Write the character and attribute to screen

os_output_char_done:
	call os_inc_cursor

	pop rax
	pop rbx
	pop rcx
	pop rdx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_output_chars -- Displays text
;  IN:	RSI = message location (A string, not zero-terminated)
;	RCX = number of chars to print
; OUT:	All registers preserved
os_output_chars:
	push rdi
	push rsi
	push rcx
	push rax

	cld				; Clear the direction flag.. we want to increment through the string
	mov ah, 0x07			; Store the attribute into AH so STOSW can be used later on

os_output_chars_nextchar:
	cmp rcx, 0
	je os_output_chars_done
	sub rcx, 1
	lodsb				; Get char from string and store in AL
	cmp al, 13			; Check if there was a newline character in the string
	je os_output_chars_newline	; If so then we print a new line
	cmp al, 10			; Check if there was a newline character in the string
	je os_output_chars_newline	; If so then we print a new line
	cmp al, 9
	je os_output_chars_tab
	call os_output_char
	jmp os_output_chars_nextchar

os_output_chars_newline:
	mov al, [rsi]
	cmp al, 10
	je os_output_chars_newline_skip_LF
	call os_print_newline
	jmp os_output_chars_nextchar

os_output_chars_newline_skip_LF:
	cmp rcx, 0
	je os_output_chars_newline_skip_LF_nosub
	sub rcx, 1
os_output_chars_newline_skip_LF_nosub:
	add rsi, 1
	call os_print_newline
	jmp os_output_chars_nextchar

os_output_chars_tab:
	push rcx
	mov ax, [os_Screen_Cursor_Col]	; Grab the current cursor X value (ex 7)
	mov cx, ax
	add ax, 8			; Add 8 (ex 15)
	shr ax, 3			; Clear lowest 3 bits (ex 8)
	shl ax, 3			; Bug? 'xor al, 7' doesn't work...
	sub ax, cx			; (ex 8 - 7 = 1)
	mov cx, ax
	mov al, ' '
os_output_chars_tab_next:
	call os_output_char
	sub cx, 1
	cmp cx, 0
	jne os_output_chars_tab_next
	pop rcx
	jmp os_output_chars_nextchar

os_output_chars_done:
	pop rax
	pop rcx
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_scroll_screen -- Scrolls the screen up by one line
;  IN:	Nothing
; OUT:	All registers preserved
os_screen_scroll:
	push rsi
	push rdi
	push rcx
	push rax
	pushfq

	cld				; Clear the direction flag as we want to increment through memory

	xor ecx, ecx

	mov rsi, os_screen 		; Start of video text memory for row 2
	add rsi, 0xA0
	mov rdi, os_screen 		; Start of video text memory for row 1
	mov cx, 1920			; 80 x 24
	rep movsw			; Copy the Character and Attribute

	; Clear the last line in video memory
	mov ax, 0x0720			; 0x07 for black background/white foreground, 0x20 for space (black) character
	mov cx, 80
	rep stosw			; Store word in AX to RDI, RCX times
	call os_screen_update

os_screen_scroll_done:
	popfq
	pop rax
	pop rcx
	pop rdi
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_screen_clear -- Clear the screen
;  IN:	Nothing
; OUT:	All registers preserved
os_screen_clear:
	push rdi
	push rcx
	push rax
	pushfq

	cld				; Clear the direction flag as we want to increment through memory

	xor ecx, ecx

	mov ax, 0x0720			; 0x07 for black background/white foreground, 0x20 for space (black) character
	mov rdi, os_screen		; Address for start of frame buffer
	mov cx, 2000			; 80 x 25
	rep stosw			; Clear the screen. Store word in AX to RDI, RCX times
	call os_screen_update

os_screen_clear_done:
	popfq
	pop rax
	pop rcx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_screen_update -- Manually refresh the screen from the frame buffer
;  IN:	Nothing
; OUT:	All registers preserved
os_screen_update:
	push rsi
	push rdi
	push rcx
	pushfq

	cld				; Clear the direction flag as we want to increment through memory

	mov rsi, os_screen
	mov rdi, 0xb8000
	mov cx, 2000			; 80 x 25
	rep movsw

	popfq
	pop rcx
	pop rdi
	pop rsi
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
