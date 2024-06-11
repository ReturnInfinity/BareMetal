; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; System Functions
; =============================================================================


; -----------------------------------------------------------------------------
; b_system - Call misc OS sub-functions
; IN:	RCX = Function
;	RAX = Variable 1
;	RDX = Variable 2
; OUT:	RAX = Result 1, dependant on system call
;	RDX = Result 2, dependant on system call
b_system:
;	cmp rcx, X
;	je b_system_
	cmp rcx, 2
	je b_system_smp_lock
	cmp rcx, 3
	je b_system_smp_unlock
	cmp rcx, 4
	je b_system_debug_dump_mem
	cmp rcx, 5
	je b_system_debug_dump_rax
	cmp rcx, 6
	je b_system_delay
	cmp rcx, 7
	je b_system_net_status
	cmp rcx, 8
	je b_system_mem_get_free
	cmp rcx, 9
	je b_system_smp_numcores
	cmp rcx, 10
	je b_system_smp_set
	cmp rcx, 11
	je b_system_smp_busy
	cmp rcx, 256
	je b_system_reset
	ret

b_system_smp_lock:
	call b_smp_lock
	ret

b_system_smp_unlock:
	call b_smp_unlock
	ret

b_system_debug_dump_mem:
	push rsi
	push rcx
	mov rsi, rax
	mov rcx, rdx
	call os_debug_dump_mem
	pop rcx
	pop rsi
	ret

b_system_debug_dump_rax:
	call os_debug_dump_rax
	ret

b_system_delay:
	call os_delay
	ret

b_system_net_status:
	call b_net_status
	ret

b_system_mem_get_free:
	xor eax, eax
	mov eax, [os_MemAmount]
	ret

b_system_smp_numcores:
	xor eax, eax
	mov ax, [os_NumCores]
	ret

b_system_smp_set:
	push rcx
	mov rcx, rdx
	call b_smp_set
	pop rcx
	ret

b_system_smp_busy:
	call b_smp_busy
	ret

b_system_reset:
	xor eax, eax
	call b_smp_get_id		; Reset all other cpu cores
	mov rbx, rax
	mov rsi, 0x0000000000005100	; Location in memory of the Pure64 CPU data
b_system_reset_next_ap:
	test cx, cx
	jz b_system_reset_no_more_aps
	lodsb				; Load the CPU APIC ID
	cmp al, bl
	je b_system_reset_skip_ap
	call b_smp_reset		; Reset the CPU
b_system_reset_skip_ap:
	dec cx
	jmp b_system_reset_next_ap
b_system_reset_no_more_aps:
	int 0x81			; Reset this core
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_delay -- Delay by X eights of a second
; IN:	RAX = Time in eights of a second
; OUT:	All registers preserved
; A value of 8 in RAX will delay 1 second and a value of 1 will delay 1/8 of a second
; This function depends on the RTC (IRQ 8) so interrupts must be enabled.
os_delay:
	push rcx
	push rax

;	mov rcx, [os_ClockCounter]	; Grab the initial timer counter. It increments 8 times a second
;	add rax, rcx			; Add RCX so we get the end time we want
;os_delay_loop:
;	cmp qword [os_ClockCounter], rax	; Compare it against our end time
;	jle os_delay_loop		; Loop if RAX is still lower

	pop rax
	pop rcx
	ret
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


; -----------------------------------------------------------------------------
; os_virt_to_phys -- Function to convert a virtual address to a physical address
; IN:	RAX = Virtual Memory Address
; OUT:	RAX = Physical Memory Address
;	All other registers preserved
; NOTE: BareMetal uses two ranges of memory. One physical 1-to-1 map and one virtual
;	range for free memory
os_virt_to_phys:
	push r15
	push rbx

	mov r15, 0xFFFF800000000000	; Starting address of the higher half
	cmp rax, r15			; Check if RAX is in the upper canonical range
	jb os_virt_to_phys_done		; If not, it is already a physical address - bail out
	mov rbx, rax			; Save RAX
	and rbx, 0x1FFFFF		; Save the low 20 bits
	mov r15, 0x7FFFFFFFFFFF
	and rax, r15
	mov r15, sys_pdh		; Location of virtual memory PDs
	shr rax, 21			; Convert 2MB page to entry
	shl rax, 3
	add r15, rax
	mov rax, [r15]			; Load the entry into RAX
	shr rax, 8			; Clear the low 8 bits
	shl rax, 8
	add rax, rbx

os_virt_to_phys_done:
	pop rbx
	pop r15
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_stub -- A function that just returns
os_stub:
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
