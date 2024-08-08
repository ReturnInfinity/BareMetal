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
	call b_delay
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
; b_delay -- Delay by X microseconds
; IN:	RAX = Time microseconds
; OUT:	All registers preserved
; Note:	There are 1,000,000 microseconds in a second
;	There are 1,000 milliseconds in a second
b_delay:
	push rdx
	push rcx
	push rbx
	push rax

	mov rbx, rax			; Save delay to RBX
	xor edx, edx
	mov ecx, HPET_GEN_CAP
	call os_hpet_read		; Get HPET General Capabilities and ID Register
	shr rax, 32
	mov rcx, rax			; RCX = RAX >> 32 (timer period in femtoseconds)
	mov rax, 1000000000
	div rcx				; Divide 10E9 (RDX:RAX) / RCX (converting from period in femtoseconds to frequency in MHz)
	mul rbx				; RAX *= RBX, should get number of HPET cycles to wait, save result in RBX
	mov rbx, rax
	mov ecx, HPET_MAIN_COUNTER
	call os_hpet_read		; Get HPET counter in RAX
	add rbx, rax			; RBX += RAX Until when to wait
; Setup a one shot HPET interrupt when main counter=RBX
	mov ecx, HPET_TIMER_0_CONF
	call os_hpet_read
	mov rax, (2 << 9) | (1 << 2)	; IRQ 2, interrupts enabled
	call os_hpet_write
	mov rax, rbx
	mov ecx, HPET_TIMER_0_COMP
	call os_hpet_write
b_delay_loop:				; Stay in this loop until the HPET timer reaches the expected value
	mov ecx, HPET_MAIN_COUNTER
	call os_hpet_read		; Get HPET counter in RAX
	cmp rax, rbx			; If RAX >= RBX then jump to end, otherwise jump to loop
	jae b_delay_end
	hlt				; Otherwise halt and the CPU will wait for an interrupt
	jmp b_delay_loop
b_delay_end:

	pop rax
	pop rbx
	pop rcx
	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; cls - Clear screen
cls:
	push rax
	push rcx
	push rdx
	push rdi
	xor eax, eax
	xor ecx, ecx
	xor edx, edx
	mov ax, [os_screen_x]
	mov cx, [os_screen_y]
	mul ecx
	mov ecx, eax
	mov rdi, [os_screen_lfb]
	mov eax, 0x00404040
	rep stosd
	pop rdi
	pop rdx
	pop rcx
	pop rax
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; reboot -- Reboot the computer
reboot:
	mov al, PS2_COMMAND_RESET_CPU
	call ps2_send_cmd
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
