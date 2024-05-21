; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; 64-bit initialization
; =============================================================================


; -----------------------------------------------------------------------------
init_64:
	; Configure the keyboard
	call keyboard_init

	; Configure the serial port
	call serial_init

	; Mask all PIC interrupts
	mov al, 0xFF
	out 0x21, al
	out 0xA1, al

	; Clear all memory after the kernel up to 2MiB
	mov edi, os_SystemVariables
	mov ecx, 122880			; Clear 960 KiB
	xor eax, eax
	rep stosq

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
	mov rax, keyboard
	call create_gate
	mov edi, 0x80
	mov rax, ap_wakeup
	call create_gate
	mov edi, 0x81
	mov rax, ap_reset
	call create_gate

	; Grab data from Pure64's InfoMap
	xor eax, eax
	xor ebx, ebx
	xor ecx, ecx
	mov esi, 0x00005008		; BSP_ID
	lodsd				; Load the BSP ID
	mov esi, 0x00005012
	lodsw				; Load the number of activated cores
	mov cx, ax			; Save it to CX
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
	push rax			; Save the free RAM size
	mov [os_MemAmount], eax		; In MiB's
	mov esi, 0x00005040		; HPET
	lodsq
	mov [os_HPET_Address], rax
	mov esi, 0x00005050
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
	lodsd
	mov [os_screen_ppsl], eax
	lodsb
	mov [os_screen_bpp], al
	mov esi, 0x00005090		; PCIe bus count
	lodsw
	mov [os_pcie_count], ax
	xor eax, eax
	mov esi, 0x00005604		; IOAPIC
	lodsd
	mov [os_IOAPICAddress], rax

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
	; The top 2MB page of RAM is for the stack
	; Divide it evenly between the available CPUs
	; Take the last free page of RAM and remap it
	pop rax				; Restore free RAM size
	shl rax, 2			; Quick multiply by 2
	add rax, sys_pdh
	mov rsi, rax
	mov rax, [rsi]
	mov [rsi+8], rax
	xor eax, eax
	mov [rsi], rax
	mov rbx, app_start
	mov eax, [os_MemAmount]		; In MiB's
	add eax, 2
	shl rax, 20
	add rax, rbx
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
