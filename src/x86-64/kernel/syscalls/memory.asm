; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2016 Return Infinity -- see LICENSE.TXT
;
; Memory functions
; =============================================================================


; -----------------------------------------------------------------------------
; b_mem_allocate -- Allocates the requested number of 2 MiB pages
;  IN:	RCX = Number of pages to allocate
; OUT:	RAX = Starting address (Set to 0 on failure)
; This function will only allocate continuous pages
b_mem_allocate:
	push rsi
	push rdx
	push rbx

	test ecx, ecx
	jz b_mem_allocate_fail		; At least 1 page must be allocated

	; Here, we'll load the last existing page of memory in RSI.
	; RAX and RSI instructions are purposefully interleaved.

	mov esi, os_MemoryMap		; First available memory block
	mov eax, [os_MemAmount]		; Total memory in MiB from a double-word
	mov edx, esi			; Keep os_MemoryMap unmodified for later in RDX
	shr eax, 1			; Divide actual memory by 2

	sub esi, 1
	std				; Set direction flag to backward
	add rsi, rax			; RSI now points to the last page

b_mem_allocate_start:			; Find a free page of memory, from the end.
	mov ebx, ecx			; RBX is our temporary counter

b_mem_allocate_nextpage:
	lodsb
	cmp rsi, rdx			; We have hit the start of the memory map, no more free pages
	je b_mem_allocate_fail

	cmp al, 1
	jne b_mem_allocate_start	; Page is taken, start counting from scratch

	dec ebx				; We found a page! Any page left to find?
	jnz b_mem_allocate_nextpage

b_mem_allocate_mark:			; We have a suitable free series of pages. Allocate them.
	cld				; Set direction flag to forward

	xchg rdi, rsi			; We swap rdi and rsi to keep rdi contents.
	

	; Instructions are purposefully swapped at some places here to avoid
	; direct dependencies line after line.
	mov r8, rcx			; Keep RCX as is for the 'rep stosb' to come
	add rdi, 1
	xor eax, eax
	mov al, 2
	mov rbx, rdi			; RBX points to the starting page
	rep stosb
	mov rdi, rsi			; Restoring RDI
	sub rbx, rdx			; RBX now contains the memory page number
	mov rcx, r8 			; Restore RCX

	; Only dependency left is between the two next lines.
	shl rbx, 21			; Quick multiply by 2097152 (2 MiB) to get the starting memory address
	mov rax, rbx			; Return the starting address in RAX
	jmp b_mem_allocate_end

b_mem_allocate_fail:
	cld				; Set direction flag to forward
	xor eax, eax			; Failure so set RAX to 0 (No pages allocated)

b_mem_allocate_end:
	pop rbx
	pop rdx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_mem_release -- Frees the requested number of 2 MiB pages
;  IN:	RAX = Starting address
;	RCX = Number of pages to free
; OUT:	RCX = Number of pages freed
b_mem_release:
	push rdi
	push rcx
	push rax

	shr rax, 21			; Quick divide by 2097152 (2 MiB) to get the starting page number
	
	lea edi, [rax+os_MemoryMap]
	xor eax, eax
	mov al, 1
	rep stosb

	pop rax
	pop rcx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_mem_get_free -- Returns the number of 2 MiB pages that are available
;  IN:	Nothing
; OUT:	RCX = Number of free 2 MiB pages
b_mem_get_free:
	push rsi
	push rbx
	push rax
	push rdi
	
	mov esi, os_MemoryMap
	mov rax, [rsi]
	add esi, 8
	xor ecx, ecx
	mov ebx, 8192	; 65536/8
	xor edx, edx
b_mem_get_free_next:
	mov rdi, [rsi] ; next chunk
	
	add esi, 8
	cmp al, 1	; 1° byte
	sete dl
	add ecx, edx

	shr rax, 8	; 2° byte
	cmp al, 1
	sete dl
	add ecx, edx	
	
	shr rax, 8	; 3° byte
	cmp al, 1
	sete dl
	add ecx, edx
	
	shr eax, 8	; 4° byte
	cmp al, 1
	sete dl
	add ecx, edx	
	
	shr eax, 8	; 5° byte
	cmp al, 1
	sete dl
	add ecx, edx
	
	shr eax, 8	; 6° byte
	cmp al, 1
	sete dl
	add ecx, edx
	
	shr eax, 8	; 7° byte
	cmp al, 1
	sete dl
	add ecx, edx
	
	mov rax, rdi	; put next chuck to rax
	sub ebx, 1
	jnz b_mem_get_free_next

b_mem_get_free_end:
	pop rdi
	pop rax
	pop rbx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
