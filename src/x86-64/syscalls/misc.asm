; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2017 Return Infinity -- see LICENSE.TXT
;
; Misc Functions
; =============================================================================


; -----------------------------------------------------------------------------
; os_delay -- Delay by X eights of a second
; IN:	RAX = Time in eights of a second
; OUT:	All registers preserved
; A value of 8 in RAX will delay 1 second and a value of 1 will delay 1/8 of a second
; This function depends on the RTC (IRQ 8) so interrupts must be enabled.
os_delay:
	push rcx
	push rax

	mov rcx, [os_ClockCounter]	; Grab the initial timer counter. It increments 8 times a second
	add rax, rcx			; Add RCX so we get the end time we want
os_delay_loop:
	cmp qword [os_ClockCounter], rax	; Compare it against our end time
	jle os_delay_loop		; Loop if RAX is still lower

	pop rax
	pop rcx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_system_config - View or modify system configuration options
; IN:	RDX = Function #
;	RAX = Variable
; OUT:	RAX = Result
;	All other registers preserved
b_system_config:
	cmp rdx, 0
	je b_system_config_timecounter
	cmp rdx, 3
	je b_system_config_networkcallback_get
	cmp rdx, 4
	je b_system_config_networkcallback_set
	cmp rdx, 5
	je b_system_config_clockcallback_get
	cmp rdx, 6
	je b_system_config_clockcallback_set
	cmp rdx, 30
	je b_system_config_mac
	ret

b_system_config_timecounter:
	mov rax, [os_ClockCounter]	; Grab the timer counter value. It increments 8 times a second
	ret

b_system_config_networkcallback_get:
	mov rax, [os_NetworkCallback]
	ret

b_system_config_networkcallback_set:
	mov qword [os_NetworkCallback], rax
	ret

b_system_config_clockcallback_get:
	mov rax, [os_ClockCallback]
	ret

b_system_config_clockcallback_set:
	mov qword [os_ClockCallback], rax
	ret

b_system_config_mac:
	call b_net_status
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_system_misc - Call misc OS sub-functions
; IN:	RDX = Function #
;	RAX = Variable 1
;	RCX = Variable 2
; OUT:	RAX = Result 1, dependant on system call
;	RCX = Result 2, dependant on system call
b_system_misc:
;	cmp rdx, X
;	je b_system_misc_
	cmp rdx, 1
	je b_system_misc_smp_get_id
	cmp rdx, 2
	je b_system_misc_smp_lock
	cmp rdx, 3
	je b_system_misc_smp_unlock
	cmp rdx, 4
	je b_system_misc_debug_dump_mem
	cmp rdx, 5
	je b_system_misc_debug_dump_rax
	cmp rdx, 6
	je b_system_misc_delay
	cmp rdx, 7
	je b_system_misc_ethernet_status
	cmp rdx, 8
	je b_system_misc_mem_get_free
	cmp rdx, 9
	je b_system_misc_smp_numcores
;	cmp rdx, 10
;	je b_system_misc_smp_queuelen
	cmp rdx, 256
	je b_system_misc_reset
	ret

b_system_misc_smp_get_id:
	call b_smp_get_id
	ret

b_system_misc_smp_lock:
	call b_smp_lock
	ret

b_system_misc_smp_unlock:
	call b_smp_unlock
	ret

b_system_misc_debug_dump_mem:
	call os_debug_dump_mem
	ret

b_system_misc_debug_dump_rax:
	call os_debug_dump_rax
	ret

b_system_misc_delay:
	call os_delay
	ret

b_system_misc_ethernet_status:
	call b_net_status
	ret

b_system_misc_mem_get_free:
	call b_mem_get_free
	ret

b_system_misc_smp_numcores:
	xor eax, eax
	mov ax, [os_NumCores]
	ret

b_system_misc_reset:
	xor eax, eax
	mov qword [os_NetworkCallback], rax	; clear callbacks
	mov qword [os_ClockCallback], rax
	call b_smp_get_id		; Reset all other cpu cores
	mov rbx, rax
	mov rsi, 0x0000000000005100	; Location in memory of the Pure64 CPU data
b_system_misc_reset_next_ap:
	test cx, cx
	jz b_system_misc_reset_no_more_aps
	lodsb				; Load the CPU APIC ID
	cmp al, bl
	je b_system_misc_reset_skip_ap
	call b_smp_reset		; Reset the CPU
b_system_misc_reset_skip_ap:
	dec cx
	jmp b_system_misc_reset_next_ap
b_system_misc_reset_no_more_aps:
	call init_memory_map		; Clear memory table
	int 0x81			; Reset this core
; -----------------------------------------------------------------------------


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
os_debug_dump_eax:
	rol eax, 8
	call os_debug_dump_al
	rol eax, 8
	call os_debug_dump_al
	rol eax, 16
os_debug_dump_ax:
	rol ax, 8
	call os_debug_dump_al
	rol ax, 8
os_debug_dump_al:
	push rbx
	push rax
	mov rbx, hextable
	push rax			; Save RAX since we work in 2 parts
	shr al, 4			; Shift high 4 bits into low 4 bits
	xlatb
	mov [tchar+0], al
	pop rax
	and al, 0x0f			; Clear the high 4 bits
	xlatb
	mov [tchar+1], al
	push rsi
	push rcx
	mov rsi, tchar
	mov rcx, 2
	call b_output
	pop rcx
	pop rsi
	pop rax
	pop rbx
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
	mov rax, rsi
	and rax, 0x0F			; Isolate the low 4 bytes of RSI
	add rcx, rax			; Add to round up the number of bytes needed
	mov rdx, rcx			; Save the total number of bytes to display
	add rdx, 15			; Make sure we print out another line if needed

	and cl, 0xF0
	and dl, 0xF0

	shr rsi, 4			; Round the starting memory address
	shl rsi, 4

os_debug_dump_mem_print_address:
	push rsi
	push rcx
	mov rsi, os_debug_dump_mem_chars
	mov rcx, 2
	call b_output
	pop rcx
	pop rsi

	mov rax, rsi
	call os_debug_dump_rax

	push rsi
	push rcx
	mov rsi, os_debug_dump_mem_chars+2
	mov rcx, 3
	call b_output
	pop rcx
	pop rsi

os_debug_dump_mem_print_contents:
	push rcx
	mov rcx, 16
os_debug_dump_mem_print_contents_next:
	lodsb
	call os_debug_dump_al
	push rsi
	push rcx
	mov rsi, os_debug_dump_mem_chars+3
	cmp rcx, 9
	mov rcx, 0
	jne singlespace
	add rcx, 1
singlespace:
	add rcx, 1
	call b_output
	pop rcx
	pop rsi
	dec rcx
	cmp rcx, 0
	jne os_debug_dump_mem_print_contents_next
	pop rcx

os_debug_dump_mem_print_ascii:
	sub rsi, 0x10
	xor rcx, rcx			; Clear the counter
os_debug_dump_mem_print_ascii_next:
	lodsb
;	call os_output_char
	inc rcx
	cmp rcx, 16
	jne os_debug_dump_mem_print_ascii_next
	push rsi
	push rcx
	mov rsi, newline
	mov rcx, 1
	call b_output
	pop rcx
	pop rsi
	sub rdx, 16
	test rdx, rdx
	jz os_debug_dump_mem_done
	jmp os_debug_dump_mem_print_address

os_debug_dump_mem_done:
	pop rax
	pop rcx
	pop rdx
	pop rsi
	ret

os_debug_dump_mem_chars: db '0x:    '
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; reboot -- Reboot the computer
reboot:
	in al, 0x64
	test al, 00000010b		; Wait for an empty Input Buffer
	jne reboot
	mov al, 0xFE
	out 0x64, al			; Send the reboot call to the keyboard controller
	jmp reboot
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
