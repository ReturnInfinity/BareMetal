; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2017 Return Infinity -- see LICENSE.TXT
;
; The BareMetal exokernel.
; =============================================================================


USE64
ORG 0x0000000000100000

%DEFINE BAREMETAL_VER 'v1.0.0 (November 13, 2016)', 13, 'Copyright (C) 2008-2017 Return Infinity', 13, 0
%DEFINE BAREMETAL_API_VER 1
KERNELSIZE	equ 10240		; Pad the kernel to this length


kernel_start:
	jmp start			; Skip over the function call index
	nop
	db 'BAREMETAL'

align 16
	dq b_output			; 0x0010
	dq b_output_chars		; 0x0018
	dq b_input			; 0x0020
	dq b_input_key			; 0x0028
	dq b_smp_set			; 0x0030
	dq b_smp_config			; 0x0038
	dq b_mem_allocate		; 0x0040
	dq b_mem_release		; 0x0048
	dq b_net_tx			; 0x0050
	dq b_net_rx			; 0x0058
	dq b_disk_read			; 0x0060
	dq b_disk_write			; 0x0068
	dq b_system_config		; 0x0070
	dq b_system_misc		; 0x0078

align 16
start:
	call init_64			; After this point we are in a working 64-bit environment
	call init_pci			; Initialize the PCI bus
	call init_hdd			; Initialize the disk
	call init_net			; Initialize the network

	; Copy the payload after the kernel to the proper address
	mov rsi, 0x100000 + KERNELSIZE	; Payload starts right after the kernel
	mov rdi, 0x200000
	mov rcx, 2048
	rep movsq			; Copy 16384 bytes

	; Set the payload to run
	mov qword [os_ClockCallback], init_process

	; Fall through to ap_clear as align fills the space with No-Ops
	; At this point the BSP is just like one of the AP's

align 16
ap_clear:				; All cores start here on first start-up and after an exception
	cli				; Disable interrupts on this core

	; Get local ID of the core
	mov rsi, [os_LocalAPICAddress]	; We can't use b_smp_get_id as no configured stack yet
	xor eax, eax			; Clear Task Priority (bits 7:4) and Task Priority Sub-Class (bits 3:0)
	mov dword [rsi+0x80], eax	; APIC Task Priority Register (TPR)
	mov eax, dword [rsi+0x20]	; APIC ID in upper 8 bits
	shr eax, 24			; Shift to the right and AL now holds the CPU's APIC ID
	mov ebx, eax

	; Clear the entry in the work table
	mov rdi, os_cpu_work_table
	shl rax, 4
	add rdi, rax
	xor eax, eax
	stosq
	stosq
	mov eax, ebx

	; Set up the stack
	shl rax, 21			; Shift left 21 bits for a 2 MiB stack
	add rax, [os_StackBase]		; The stack decrements when you "push", start at 2 MiB in
	sub rax, 8
	mov rsp, rax

	sti				; Enable interrupts on this core

	; Clear registers. Gives us a clean slate to work with
	xor eax, eax			; aka r0
	xor ecx, ecx			; aka r1
	xor edx, edx			; aka r2
	xor ebx, ebx			; aka r3
	xor ebp, ebp			; aka r5, We skip RSP (aka r4) as it was previously set
	xor esi, esi			; aka r6
	xor edi, edi			; aka r7
	xor r8, r8
	xor r9, r9
	xor r10, r10
	xor r11, r11
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15

ap_check:
	call b_smp_get_work		; Check for an assigned workload
	cmp rax, 0			; If 0 then there is nothing to do
	jne ap_process

ap_halt:				; Halt until a wakeup call is received
	hlt
	jmp ap_check			; Core will jump to ap_check when it wakes up

ap_process:
	call rax			; Run the code
	jmp ap_clear			; Reset the stack, clear the registers, and wait for something else to work on

init_process:
	call b_smp_get_id		; Get the ID of the current core
	mov rcx, rax
	mov rax, 0x200000		; Payload was copied here
	call b_smp_set
	mov qword [os_ClockCallback], 0	; Clear the callback
	ret

; Includes
%include "init.asm"
%include "syscalls.asm"
%include "drivers.asm"
%include "interrupt.asm"
%include "sysvar.asm"			; Include this last to keep the read/write variables away from the code

times KERNELSIZE-($-$$) db 0		; Set the compiled kernel binary to at least this size in bytes


; =============================================================================
; EOF
