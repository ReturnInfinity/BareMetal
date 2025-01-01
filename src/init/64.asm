; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; 64-bit initialization
; =============================================================================


; -----------------------------------------------------------------------------
init_64:
	; Debug output
	mov rsi, msg_init_64
	mov rcx, 10
	call b_output

	; Clear all memory after the kernel up to 2MiB
	mov edi, os_SystemVariables
	mov ecx, 122880			; Clear 960 KiB
	xor eax, eax
	rep stosq

	; Gather data from Pure64's InfoMap
	mov esi, 0x00005060		; LAPIC
	lodsq
	mov [os_LocalAPICAddress], rax
	mov esi, 0x00005010		; CPUSPEED
	lodsw
	mov [os_CoreSpeed], ax
	mov esi, 0x00005012		; CORES_ACTIVE
	lodsw
	mov [os_NumCores], ax
	mov esi, 0x00005020		; RAMAMOUNT
	lodsd
	sub eax, 2			; Save 2 MiB for the CPU stacks
	mov [os_MemAmount], eax		; In MiB's
	mov esi, 0x00005040		; HPET
	lodsq
	mov [os_HPET_Address], rax
	lodsd
	mov [os_HPET_Frequency], eax
	lodsw
	mov [os_HPET_CounterMin], ax
	mov esi, 0x00005080		; VIDEO_*
	xor eax, eax
	lodsq
	mov [os_screen_lfb], rax
	lodsw
	mov [os_screen_x], ax
	lodsw
	mov [os_screen_y], ax
	lodsw
	mov [os_screen_ppsl], ax
	lodsw
	mov [os_screen_bpp], ax
	mov esi, 0x00005090		; PCIe bus count
	lodsw
	mov [os_pcie_count], ax
	xor eax, eax
	mov esi, 0x00005604		; IOAPIC
	lodsd
	mov [os_IOAPICAddress], rax

	; Configure the PS/2 keyboard and mouse
	call ps2_init

	; Configure the serial port
	call serial_init

	; Mask all PIC interrupts
	mov al, 0xFF
	out 0x21, al
	out 0xA1, al

	; Create exception gate stubs (Pure64 has already set the correct gate markers)
	xor edi, edi			; 64-bit IDT at linear address 0x0000000000000000
	mov ecx, 32
	mov rax, exception_gate		; A generic exception handler
make_exception_gate_stubs:
	call create_gate
	inc edi
	dec ecx
	jnz make_exception_gate_stubs

	; Set up the exception gates for all of the CPU exceptions
	xor edi, edi
	mov ecx, 21
	mov rax, exception_gate_00
make_exception_gates:
	call create_gate
	inc edi
	add rax, 24			; Each exception gate is 24 bytes
	dec rcx
	jnz make_exception_gates

	; Create interrupt gate stubs (Pure64 has already set the correct gate markers)
	mov ecx, 256-32
	mov rax, interrupt_gate
make_interrupt_gate_stubs:
	call create_gate
	inc edi
	dec ecx
	jnz make_interrupt_gate_stubs

	; Set up the IRQ handlers (Network IRQ handler is configured in init_net)
	mov edi, 0x21
	mov rax, int_keyboard
	call create_gate
	mov edi, 0x2C
	mov rax, int_mouse
	call create_gate
	mov edi, 0x80
	mov rax, ap_wakeup
	call create_gate
	mov edi, 0x81
	mov rax, ap_reset
	call create_gate

	; Set device syscalls to stub
	mov rax, os_stub
	mov rdi, os_storage_io
	stosq
	stosq
	mov rdi, os_net_transmit
	stosq
	stosq
	stosq	

	; Configure the Stack base
	mov rax, 0x200000		; Stacks start at 2MiB
	mov [os_StackBase], rax

	; Initialize the APIC
	call os_apic_init

	; Initialize the I/O APIC
	call os_ioapic_init

	; Initialize the HPET
	call os_hpet_init

	; Initialize all AP's to run our reset code. Skip the BSP
	call b_smp_get_id
	mov ebx, eax
	xor eax, eax
	mov cx, 255
	mov esi, 0x00005100		; Location in memory of the Pure64 CPU data
next_ap:
	test cx, cx
	jz no_more_aps
	lodsb				; Load the CPU APIC ID
	cmp al, bl
	je skip_ap
	call b_smp_reset		; Reset the CPU
skip_ap:
	dec cx
	jmp next_ap
no_more_aps:

	; Enable specific interrupts
	mov ecx, 1			; Keyboard IRQ
	mov eax, 0x21			; Keyboard Interrupt Vector
	call os_ioapic_mask_clear
	mov ecx, 12			; Mouse IRQ
	mov eax, 0x2C			; Mouse Interrupt Vector
	call os_ioapic_mask_clear

	; Output block to screen (1/4)
	mov ebx, 0
	call os_debug_block

	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; create_gate
; rax = address of handler
; rdi = gate # to configure
create_gate:
	push rdi
	push rax

	shl rdi, 4			; Quickly multiply rdi by 16
	stosw				; Store the low word (15..0)
	shr rax, 16
	add rdi, 4			; Skip the gate marker (selector, ist, type)
	stosw				; Store the high word (31..16)
	shr rax, 16
	stosd				; Store the high dword (63..32)
	xor eax, eax
	stosd				; Reserved bits

	pop rax
	pop rdi
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
