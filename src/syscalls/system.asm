; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; System Functions
; =============================================================================


; -----------------------------------------------------------------------------
; b_system - Call system functions
; IN:	RCX = Function
;	RAX = Variable 1
;	RDX = Variable 2
; OUT:	RAX = Result
;	All other registers preserved
b_system:
	cmp rcx, 0x80
	jge b_system_end

; Use CX register as an index to the function table
; To save memory, the functions are placed in 16-bit frames
	push rcx
	lea ecx, [b_system_table+ecx*2]	; extract function from table by index
	mov cx, [ecx]			; limit jump to 16-bit
	call rcx			; call function
	pop rcx

b_system_end:
	ret

; Basic

b_system_timecounter:
	mov ecx, 0xF0
	call os_hpet_read
	ret

b_system_free_memory:
	mov eax, [os_MemAmount]
	ret

b_system_getmouse:
	mov rax, [os_ps2_mouse]
	ret

; CPU

b_system_smp_get_id:
	call b_smp_get_id
	ret

b_system_smp_numcores:
	xor eax, eax
	mov ax, [os_NumCores]
	ret

b_system_smp_set:
	mov rcx, rdx
	call b_smp_set
	ret

b_system_smp_get:
	call b_smp_get
	ret

b_system_smp_lock:
	call b_smp_lock
	ret

b_system_smp_unlock:
	call b_smp_unlock
	ret

b_system_smp_busy:
	call b_smp_busy
	ret

b_system_tsc:
	call b_tsc
	ret

; Video

b_system_screen_lfb_get:
	mov rax, [os_screen_lfb]
	ret

b_system_screen_x_get:
	xor eax, eax
	mov ax, [os_screen_x]
	ret

b_system_screen_y_get:
	xor eax, eax
	mov ax, [os_screen_y]
	ret

b_system_screen_ppsl_get:
	xor eax, eax
	mov ax, [os_screen_ppsl]
	ret

b_system_screen_bpp_get:
	xor eax, eax
	mov ax, [os_screen_bpp]
	ret

; Network

b_system_mac_get:
	call b_net_status
	ret

; Bus

b_system_pci_read:
	call os_bus_read
	ret

b_system_pci_write:
	call os_bus_write
	ret

; Standard Output

b_system_stdout_get:
	mov rax, qword [0x100018]
	ret

b_system_stdout_set:
	mov qword [0x100018], rax
	ret

; Misc

b_system_callback_timer:
	ret

b_system_callback_network:
	ret

b_system_callback_keyboard:
	ret

b_system_callback_mouse:
	mov [os_MouseCallback], rax
	ret

b_system_debug_dump_mem:
	push rsi
	mov rsi, rax
	mov rcx, rdx
	call os_debug_dump_mem
	pop rsi
	ret

b_system_debug_dump_rax:
	call os_debug_dump_rax
	ret

b_system_delay:
	call b_delay
	ret

b_system_reset:
	xor eax, eax
	call b_smp_get_id		; Reset all other cpu cores
	mov rbx, rax
	mov esi, 0x00005100		; Location in memory of the Pure64 CPU data
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

b_system_reboot:
	call reboot

b_system_shutdown:
	mov ax, 0x2000
	mov dx, 0xB004
	out dx, ax			; Bochs/QEMU < v2
	mov dx, 0x0604
	out dx, ax			; QEMU
	mov ax, 0x3400
	mov dx, 0x4004
	out dx, ax			; VirtualBox
	jmp $
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
	movzx eax, byte [os_HPET_IRQ]
	shl rax, 9
	or rax, (1 << 2)
	call os_hpet_write		; Value to write is (os_HPET_IRQ<<9 | 1<<2)
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
; b_tsc -- Read the Time-Stamp Counter and store in RAX
; IN:	Nothing
; OUT:	RAX = Current Time-Stamp Counter value
;	All other registers preserved
b_tsc:
	push rdx
	rdtsc				; Reads the TSC into EDX:EAX
	shl rdx, 32			; Shift the low 32-bits to the high 32-bits
	or rax, rdx			; Combine RAX and RDX
	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_delay -- Delay by X HPET ticks
; IN:	RAX = HPET ticks
; OUT:	All registers preserved
os_delay:
	push rcx
	push rbx
	push rax

	xor ebx, ebx
	mov ecx, HPET_MAIN_COUNTER
	call os_hpet_read		; Get HPET counter in RAX
	add rbx, rax			; RBX += RAX Until when to wait
os_delay_loop:				; Stay in this loop until the HPET timer reaches the expected value
	mov ecx, HPET_MAIN_COUNTER
	call os_hpet_read		; Get HPET counter in RAX
	cmp rax, rbx			; If RAX >= RBX then jump to end, otherwise jump to loop
	jb os_delay_loop

	pop rax
	pop rbx
	pop rcx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; reboot -- Reboot the computer
reboot:
	mov al, PS2_RESET_CPU
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
b_user:
os_stub:
none:
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; System function index table
b_system_table:
; Basic
	dw b_system_timecounter		; 0x00
	dw b_system_free_memory		; 0x01
	dw b_system_getmouse		; 0x02
	dw none				; 0x03
	dw none				; 0x04
	dw none				; 0x05
	dw none				; 0x06
	dw none				; 0x07
	dw none				; 0x08
	dw none				; 0x09
	dw none				; 0x0A
	dw none				; 0x0B
	dw none				; 0x0C
	dw none				; 0x0D
	dw none				; 0x0E
	dw none				; 0x0F

; CPU
	dw b_system_smp_get_id		; 0x10
	dw b_system_smp_numcores	; 0x11
	dw b_system_smp_set		; 0x12
	dw b_system_smp_get		; 0x13
	dw b_system_smp_lock		; 0x14
	dw b_system_smp_unlock		; 0x15
	dw b_system_smp_busy		; 0x16
	dw none				; 0x17
	dw none				; 0x18
	dw none				; 0x19
	dw none				; 0x1A
	dw none				; 0x1B
	dw none				; 0x1C
	dw none				; 0x1D
	dw none				; 0x1E
	dw b_system_tsc			; 0x1F

; Video
	dw b_system_screen_lfb_get	; 0x20
	dw b_system_screen_x_get	; 0x21
	dw b_system_screen_y_get	; 0x22
	dw b_system_screen_ppsl_get	; 0x23
	dw b_system_screen_bpp_get	; 0x24
	dw none				; 0x25
	dw none				; 0x26
	dw none				; 0x27
	dw none				; 0x28
	dw none				; 0x29
	dw none				; 0x2A
	dw none				; 0x2B
	dw none				; 0x2C
	dw none				; 0x2D
	dw none				; 0x2E
	dw none				; 0x2F

; Network
	dw b_system_mac_get		; 0x30
	dw none				; 0x31
	dw none				; 0x32
	dw none				; 0x33
	dw none				; 0x34
	dw none				; 0x35
	dw none				; 0x36
	dw none				; 0x37
	dw none				; 0x38
	dw none				; 0x39
	dw none				; 0x3A
	dw none				; 0x3B
	dw none				; 0x3C
	dw none				; 0x3D
	dw none				; 0x3E
	dw none				; 0x3F

; Storage
	dw none				; 0x40
	dw none				; 0x41
	dw none				; 0x42
	dw none				; 0x43
	dw none				; 0x44
	dw none				; 0x45
	dw none				; 0x46
	dw none				; 0x47
	dw none				; 0x48
	dw none				; 0x49
	dw none				; 0x4A
	dw none				; 0x4B
	dw none				; 0x4C
	dw none				; 0x4D
	dw none				; 0x4E
	dw none				; 0x4F

; Misc
	dw b_system_pci_read		; 0x50
	dw b_system_pci_write		; 0x51
	dw b_system_stdout_set		; 0x52
	dw b_system_stdout_get		; 0x53
	dw none				; 0x54
	dw none				; 0x55
	dw none				; 0x56
	dw none				; 0x57
	dw none				; 0x58
	dw none				; 0x59
	dw none				; 0x5A
	dw none				; 0x5B
	dw none				; 0x5C
	dw none				; 0x5D
	dw none				; 0x5E
	dw none				; 0x5F
	dw b_system_callback_timer	; 0x60
	dw b_system_callback_network	; 0x61
	dw b_system_callback_keyboard	; 0x62
	dw b_system_callback_mouse	; 0x63
	dw none				; 0x64
	dw none				; 0x65
	dw none				; 0x66
	dw none				; 0x67
	dw none				; 0x68
	dw none				; 0x69
	dw none				; 0x6A
	dw none				; 0x6B
	dw none				; 0x6C
	dw none				; 0x6D
	dw none				; 0x6E
	dw none				; 0x6F

; Misc
	dw b_system_debug_dump_mem	; 0x70
	dw b_system_debug_dump_rax	; 0x71
	dw b_system_delay		; 0x72
	dw none				; 0x73
	dw none				; 0x74
	dw none				; 0x75
	dw none				; 0x76
	dw none				; 0x77
	dw none				; 0x78
	dw none				; 0x79
	dw none				; 0x7A
	dw none				; 0x7B
	dw none				; 0x7C
	dw b_system_reset		; 0x7D
	dw b_system_reboot		; 0x7E
	dw b_system_shutdown		; 0x7F
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
