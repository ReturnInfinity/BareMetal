; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2016 Return Infinity -- see LICENSE.TXT
;
; INIT_64
; =============================================================================


; -----------------------------------------------------------------------------
init_64:
	; Clear system variables area
	mov edi, os_SystemVariables
	mov ecx, 122880            ; Clear 960 KiB
	xor eax, eax
	rep stosq                  ; Store rax to [rdi], rcx - 1, rdi + 8, if rcx > 0 then do it again

	; Set screen variables and clear screen
	mov word [os_Screen_Rows], 25
	mov word [os_Screen_Cols], 80
	mov [os_Screen_Cursor_Row], eax ; set Row,Col to zero
;	mov word [os_Screen_Cursor_Col]
	call os_screen_clear

	; Create the 64-bit IDT (at linear address 0x0000000000000000) as defined by Pure64
	xor edi, edi

	; Create exception gate stubs (Pure64 has already set the correct gate markers)
	lea ecx, [rdi+32]
	mov eax, exception_gate
make_exception_gate_stubs:
	call create_gate
	add edi, 1
	sub ecx, 1
	jnz make_exception_gate_stubs

	; Create interrupt gate stubs (Pure64 has already set the correct gate markers)
	mov ecx, 256-32
	mov eax, interrupt_gate
make_interrupt_gate_stubs:
	call create_gate
	add edi, 1
	sub ecx, 1
	jnz make_interrupt_gate_stubs

	; Set up the exception gates for all of the CPU exceptions
	xor edi, edi
	lea ecx, [rdi+20]
	mov eax, exception_gate_00
make_exception_gates:
	call create_gate
	add rdi, 1
	add eax, 16			; The exception gates are aligned at 16 bytes
	sub ecx, 1
	jnz make_exception_gates

	; Set up the IRQ handlers (Network IRQ handler is configured in init_net)
	lea edi, [rcx+0x21]	; ecx is zero
	mov eax, keyboard
	call create_gate
	add edi, 0x1
	mov eax, cascade
	call create_gate
	add edi, 0x6
	mov eax, rtc
	call create_gate
	add edi, 0x58
	mov eax, ap_wakeup
	call create_gate
	add edi, 0x1
	mov eax, ap_reset
	call create_gate

	; Set up RTC
	; Rate defines how often the RTC interrupt is triggered
	; Rate is a 4-bit value from 1 to 15. 1 = 32768Hz, 6 = 1024Hz, 15 = 2Hz
	; RTC value must stay at 32.768KHz or the computer will not keep the correct time
	; http://wiki.osdev.org/RTC
rtc_poll:
	xor eax, eax
	mov al, 0x0A			; Status Register A
	out 0x70, al
	in al, 0x71
	test al, 0x80			; Is there an update in process?
	jne rtc_poll			; If so then keep polling
	mov al, 0x0A			; Status Register A
	out 0x70, al
	mov al, 00101101b		; RTC@32.768KHz (0010), Rate@8Hz (1101)
	out 0x71, al
	mov al, 0x0B			; Status Register B
	out 0x70, al			; Select the address
	in al, 0x71			; Read the current settings
	mov ebx, eax
	mov al, 0x0B			; Status Register B
	out 0x70, al			; Select the address
	bts ebx, 6			; Set Periodic(6)
	mov eax, ebx
	out 0x71, al			; Write the new settings
	mov al, 0x0C			; Acknowledge the RTC
	out 0x70, al
	in al, 0x71
;	mov al, 0x20			; Acknowledge the IRQ
;	out 0xA0, al
;	out 0x20, al

	; Grab data from Pure64's infomap
	mov esi, 0x5008
	mov ebx, [rsi]			; Load the BSP ID
					; Save it to EBX
	movzx ecx, word [rsi+x0a]	; Load the number of activated cores
					; Save it to ECX
	add esi, 0x58			; esi=0x5060
	mov rax, [rsi]
	mov [os_LocalAPICAddress], rax
	mov rax, [rsi+8]
	mov [os_IOAPICAddress], rax
	movzx eax, word  [rsi-0x4e]	; esi=0x5012
	mov [os_NumCores], ax
	sub esi,0x40			;esi=0x5020
	mov eax, [rsi]
	mov [os_MemAmount], eax		; In MiB's
	mov rax, [rsi+0x20]		; esi=0x5040
	mov [os_HPETAddress], rax

	; Build the OS memory table
	call init_memory_map

	; Initialize all AP's to run our reset code. Skip the BSP
	xor eax, eax
	mov esi, 0x5100		; Location in memory of the Pure64 CPU data
next_ap:
	movzx eax, byte [rsi]		; Load the CPU APIC ID
	add esi, 1
	cmp al, bl
	je skip_ap
	call b_smp_reset		; Reset the CPU
skip_ap:
	sub ecx, 1
	jnz next_ap
no_more_aps:

	; Enable specific interrupts
	xor eax, eax
	mov al, 0x01			; Keyboard IRQ
	call os_pic_mask_clear
	mov al, 0x02			; Cascade IRQ
	call os_pic_mask_clear
	mov al, 0x08			; RTC IRQ
	call os_pic_mask_clear

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


; -----------------------------------------------------------------------------
init_memory_map:			; Build the OS memory table
	push rax
	push rcx
	push rdi

	; Build a fresh memory map for the system
	mov edi, os_MemoryMap
	movzx ecx, word [os_MemAmount]
	mov [rdi], byte 0x2		; Mark the first 2MiB as in use (by Kernel and system buffers)
	add edi, 1
	shr ecx, 1			; Divide actual memory by 2
	xor eax, eax
	mov al, 1
	rep stosb
	
	;The CLI should take care of the Application memory

	; Allocate memory for CPU stacks (2 MiB's for each core)
	movzx ecx,  word [os_NumCores]	; Get the amount of cores in the system
	call b_mem_allocate		; Allocate a page for each core
	test ecx, ecx			; b_mem_allocate returns 0 on failure
	jz system_failure
	add rax, 2097152
	mov [os_StackBase], rax		; Store the Stack base address

	pop rdi
	pop rcx
	pop rax
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
system_failure:
	mov esi, memory_message
	call b_output
system_failure_hang:
	hlt
	jmp system_failure_hang
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
