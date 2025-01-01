; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Debug Functions
; =============================================================================


; -----------------------------------------------------------------------------
; os_debug_dump_(rax|eax|ax|al) -- Dump content of RAX, EAX, AX, or AL
;  IN:	RAX = content to dump
; OUT:	Nothing, all registers preserved
os_debug_dump_rax:
	rol rax, 8
	call os_debug_dump_al
	rol rax, 8
	call os_debug_dump_al
	rol rax, 8
	call os_debug_dump_al
	rol rax, 8
	call os_debug_dump_al
	rol rax, 32
os_debug_dump_eax:			; RAX is used here instead of EAX to preserve the upper 32-bits
	rol rax, 40
	call os_debug_dump_al
	rol rax, 8
	call os_debug_dump_al
	rol rax, 16
os_debug_dump_ax:
	rol ax, 8
	call os_debug_dump_al
	rol ax, 8
os_debug_dump_al:
	push rax
	push ax				; Save AX for the low nibble
	shr al, 4			; Shift the high 4 bits into the low 4, high bits cleared
	or al, '0'			; Add "0"
	cmp al, '9'+1			; Digit?
	jl os_debug_dump_al_h		; Yes, store it
	add al, 7			; Add offset for character "A"
os_debug_dump_al_h:
	mov [tchar+0], al		; Store first character
	pop ax				; Restore AX
	and al, 0x0F			; Keep only the low 4 bits
	or al, '0'			; Add "0"
	cmp al, '9'+1			; Digit?
	jl os_debug_dump_al_l		; Yes, store it
	add al, 7			; Add offset for character "A"
os_debug_dump_al_l:
	mov [tchar+1], al		; Store second character
	pop rax
	push rsi
	push rcx
	mov rsi, tchar
	mov rcx, 2
	call [0x00100018]		; b_output
	pop rcx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_debug_dump_mem -- Dump content of memory in hex format
;  IN:	RSI = starting address of memory to dump
;	RCX = number of bytes
; OUT:	Nothing, all registers preserved
os_debug_dump_mem:
	push rsi
	push rcx			; Counter
	push rdx			; Total number of bytes to display
	push rax

	test rcx, rcx			; Bail out if no bytes were requested
	jz os_debug_dump_mem_done

	push rsi			; Output '0x'
	push rcx
	mov rsi, os_debug_dump_mem_chars
	mov rcx, 2
	call b_output
	pop rcx
	pop rsi

	mov rax, rsi			; Output the memory address
	call os_debug_dump_rax
	call os_debug_newline

nextline:
	mov dx, 0
nextchar:
	cmp rcx, 0
	je os_debug_dump_mem_done_newline
	push rsi			; Output ' '
	push rcx
	mov rsi, os_debug_dump_mem_chars+3
	mov rcx, 1
	call b_output
	pop rcx
	pop rsi
	lodsb
	call os_debug_dump_al
	dec rcx
	inc rdx
	cmp dx, 16			; End of line yet?
	jne nextchar
	call os_debug_newline
	cmp rcx, 0
	je os_debug_dump_mem_done
	jmp nextline

os_debug_dump_mem_done_newline:
	call os_debug_newline

os_debug_dump_mem_done:
	pop rax
	pop rcx
	pop rdx
	pop rsi
	ret

os_debug_dump_mem_chars: db '0x: '
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_debug_newline -- Output a newline
;  IN:	Nothing
; OUT:	Nothing, all registers preserved
os_debug_newline:
	push rsi
	push rcx
	mov rsi, newline
	mov rcx, 2
	call [0x00100018]		; b_output
	pop rcx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_debug_space -- Output a space
;  IN:	Nothing
; OUT:	Nothing, all registers preserved
os_debug_space:
	push rsi
	push rcx
	mov rsi, space
	mov rcx, 1
	call [0x00100018]		; b_output
	pop rcx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_debug_block - Create a block (8x8 pixels) of colour on the screen
; IN:	EBX = Index #
os_debug_block:
	push rax
	push rbx
	push rcx
	push rdx
	push rdi

	; Calculate parameters
	push rbx
	push rax
	xor edx, edx
	xor eax, eax
	xor ebx, ebx
	mov ax, [0x00005F00 + 0x12]	; Screen Y
	add ax, 16			; Lower row
	shr ax, 1			; Quick divide by 2
	mov bx, [0x00005F00 + 0x10]	; Screen X
	shl ebx, 2			; Quick multiply by 4
	mul ebx				; Multiply EDX:EAX by EBX
	mov rdi, [0x00005F00]		; Frame buffer base
	add rdi, rax			; Offset is ((screeny - 8) / 2 + screenx * 4)
	pop rax
	pop rbx
	xor edx, edx
	mov dx, [0x00005F00 + 0x14]	; PixelsPerScanLine
	shl edx, 2			; Quick multiply by 4 for line offset
	xor ecx, ecx
	mov cx, [0x00005F00 + 0x10]	; Screen X
	shr cx, 4			; CX = total amount of 8-pixel wide blocks
	sub cx, 4
	add ebx, ecx
	shl ebx, 5			; Quick multiply by 32 (8 pixels by 4 bytes each)
	add rdi, rbx

	; Draw the 8x8 pixel block
	mov ebx, 8			; 8 pixels tall
	mov eax, 0x00F7CA54		; Return Infinity Yellow/Orange
os_debug_block_nextline:
	mov ecx, 8			; 8 pixels wide
	rep stosd
	add rdi, rdx			; Add line offset
	sub rdi, 8*4
	dec ebx
	jnz os_debug_block_nextline

	pop rdi
	pop rdx
	pop rcx
	pop rbx
	pop rax
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
