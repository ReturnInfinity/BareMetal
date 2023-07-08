; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2023 Return Infinity -- see LICENSE.TXT
;
; The BareMetal exokernel
; =============================================================================


BITS 64					; Specify 64-bit
ORG 0x0000000000100000			; The kernel needs to be loaded at this address

%DEFINE BAREMETAL_VER 'v1.0.0 (January 21, 2020)', 13, 'Copyright (C) 2008-2023 Return Infinity', 13, 0
%DEFINE BAREMETAL_API_VER 1
KERNELSIZE equ 8192			; Pad the kernel to this length


kernel_start:
	jmp start			; Skip over the function call index
	nop
	db 'BAREMETAL'			; Kernel signature

align 16
	dq b_input			; 0x0010
	dq b_output			; 0x0018
	dq b_net_tx			; 0x0020
	dq b_net_rx			; 0x0028
	dq b_storage_read		; 0x0030
	dq b_storage_write		; 0x0038
	dq b_config			; 0x0040
	dq b_system			; 0x0048

align 16
start:
	call init_64			; After this point we are in a working 64-bit environment
	call init_pci			; Initialize the PCI bus
	call init_storage		; Initialize storage
	call init_net			; Initialize the network

	mov rsi, readymsg
	mov rcx, 13
	call b_output

	; Copy the payload after the kernel to the proper address
	mov rsi, 0x100000 + KERNELSIZE	; Payload starts right after the kernel
	cmp qword [rsi], 0		; Is there a payload after the kernel?
	je ap_clear			; If not, skip to ap_clear
	mov rdi, 0x1E0000
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
	mov ebx, eax			; Save the APIC ID

	; Set up the stack
	shl rax, 16			; Shift left 16 bits for an 64 KiB stack
	add rax, [os_StackBase]		; The stack decrements when you "push", start at 64 KiB in
	add rax, 65536
	mov rsp, rax

	; Clear the entry in the work table
	mov eax, ebx			; Restore the APIC ID
	mov rdi, os_SMP
	shl rax, 3			; Quick multiply by 8 to get to proper record
	add rdi, rax
	xor eax, eax
	or al, 1			; Set bit 0 for "present"
	stosq				; Clear the code address

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

	sti				; Enable interrupts on this core

ap_check:
	call b_smp_get			; Check for an assigned workload
	and al, 0xF0			; Clear the flags
	cmp rax, 0			; If 0 then there is nothing to do
	jne ap_process

ap_halt:				; Halt until a wakeup call is received
	hlt
	jmp ap_check			; Core will jump to ap_check when it wakes up

ap_process:
	mov rcx, 1			; Set the active flag
	call b_smp_setflag
	xor ecx, ecx
	call rax			; Run the code
	jmp ap_clear			; Reset the stack, clear the registers, and wait for something else to work on

init_process:
	call b_smp_get_id		; Get the ID of the current core
	mov rcx, rax			; Copy the APIC ID for b_smp_set
	mov rax, 0x1E0000		; Payload was copied here
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
