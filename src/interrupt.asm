; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2023 Return Infinity -- see LICENSE.TXT
;
; Interrupts
; =============================================================================


; -----------------------------------------------------------------------------
; Default exception handler
align 8
exception_gate:
	mov rsi, int_string00
	call b_output
	mov rsi, exc_string
	call b_output
	jmp $				; Hang
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; Default interrupt handler
align 8
interrupt_gate:				; handler for all other interrupts
	iretq				; It was an undefined interrupt so return to caller
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; Keyboard interrupt. IRQ 0x01, INT 0x21
; This IRQ runs whenever there is input on the keyboard
align 8
keyboard:
	push rdi
	push rbx
	push rax
	pushfq
	cld				; Clear direction flag

	xor eax, eax

	in al, 0x60			; Get the scan code from the keyboard
	cmp al, 0x01
	je keyboard_escape
	cmp al, 0x2A			; Left Shift Make
	je keyboard_shift
	cmp al, 0x36			; Right Shift Make
	je keyboard_shift
	cmp al, 0xAA			; Left Shift Break
	je keyboard_noshift
	cmp al, 0xB6			; Right Shift Break
	je keyboard_noshift
	test al, 0x80
	jz keydown
	jmp keyup

keydown:
	cmp byte [key_shift], 0x00
	je keyboard_lowercase

keyboard_uppercase:
	mov rbx, keylayoutupper
	jmp keyboard_processkey

keyboard_lowercase:
	mov rbx, keylayoutlower

keyboard_processkey:			; Convert the scan code
	add rbx, rax
	mov bl, [rbx]
	mov [key], bl
	jmp keyboard_done

keyboard_escape:
	jmp reboot

keyup:
	jmp keyboard_done

keyboard_shift:
	mov byte [key_shift], 0x01
	jmp keyboard_done

keyboard_noshift:
	mov byte [key_shift], 0x00
	jmp keyboard_done

keyboard_done:
;	mov al, 0x20			; Acknowledge the IRQ
;	out 0x20, al
	mov rdi, [os_LocalAPICAddress]
	add rdi, 0xB0			; Add offset to EOI register
	xor eax, eax
	stosd				; Acknowledge the IRQ
	call b_smp_wakeup_all		; A terrible hack

	popfq
	pop rax
	pop rbx
	pop rdi
	iretq
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; Cascade interrupt. IRQ 0x02, INT 0x22
;align 8
;cascade:
;	push rax
;
;	mov al, 0x20			; Acknowledge the IRQ
;	out 0x20, al
;
;	pop rax
;	iretq
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; Real-time clock interrupt. IRQ 0x08, INT 0x28
; Currently this IRQ runs 8 times per second (As defined in init_64.asm)
; The supervisor lives here
align 8
rtc:
	push rax
	pushfq
	cld				; Clear direction flag

	add qword [os_ClockCounter], 1	; 64-bit counter started at boot-up

	cmp qword [os_ClockCallback], 0	; Is it valid?
	je rtc_end			; If not then bail out.

	; We could do a 'call [os_ClockCallback]' here but that would not be ideal.
	; A defective callback would hang the system if it never returned back to the
	; interrupt handler. Instead, we modify the stack so that the callback is
	; executed after the interrupt handler has finished. Once the callback has
	; finished, the execution flow will pick up back in the program.
	push rdi
	push rsi
	push rcx
	mov rcx, clock_callback		; RCX stores the callback function address
	mov rsi, rsp			; Copy the current stack pointer to RSI
	sub rsp, 8			; Subtract 8 since we add a 64-bit value to the stack
	mov rdi, rsp			; Copy the 'new' stack pointer to RDI
	movsq				; RCX
	movsq				; RSI
	movsq				; RDI
	movsq				; Flags
	movsq				; RAX
	lodsq				; RIP
	xchg rax, rcx
	stosq				; Callback address
	movsq				; CS
	movsq				; Flags
	lodsq				; RSP
	sub rax, 8
	stosq
	movsq				; SS
	mov [rax], rcx			; Original RIP
	pop rcx
	pop rsi
	pop rdi

rtc_end:
	mov al, 0x0C			; Select RTC register C
	out 0x70, al			; Port 0x70 is the RTC index, and 0x71 is the RTC data
	in al, 0x71			; Read the value in register C

;	mov al, 0x20			; Acknowledge the IRQ
;	out 0xA0, al
;	out 0x20, al
	push rdi
	mov rdi, [os_LocalAPICAddress]
	add rdi, 0xB0			; Add offset to EOI register
	xor eax, eax
	stosd				; Acknowledge the IRQ
	pop rdi

	popfq
	pop rax
	iretq
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; Network interrupt handler
align 8
network:
	push rdi
	push rsi
	push rcx
	push rax
	pushfq
	cld				; Clear direction flag

	call b_net_ack_int		; Call the driver function to acknowledge the interrupt internally

	bt ax, 0			; TX bit set (caused the IRQ?)
	jc network_tx			; If so then jump past RX section
	bt ax, 7			; RX bit set
	jnc network_end
network_rx_as_well:
	mov byte [os_NetActivity_RX], 1
	call b_net_rx_from_interrupt	; Call driver
	cmp qword [os_NetworkCallback], 0	; Is it valid?
	je network_end			; If not then bail out.

	; We could do a 'call [os_NetworkCallback]' here but that would not be ideal.
	; A defective callback would hang the system if it never returned back to the
	; interrupt handler. Instead, we modify the stack so that the callback is
	; executed after the interrupt handler has finished. Once the callback has
	; finished, the execution flow will pick up back in the program.
	mov rcx, network_callback	; RCX stores the callback function address
	mov rsi, rsp			; Copy the current stack pointer to RSI
	sub rsp, 8			; Subtract 8 since we add a 64-bit value to the stack
	mov rdi, rsp			; Copy the 'new' stack pointer to RDI
	movsq				; Flags
	movsq				; RAX
	movsq				; RCX
	movsq				; RSI
	movsq				; RDI
	lodsq				; RIP
	xchg rax, rcx
	stosq				; Callback address
	movsq				; CS
	movsq				; Flags
	lodsq				; RSP
	sub rax, 8
	stosq
	movsq				; SS
	mov [rax], rcx			; Original RIP
	jmp network_end

network_tx:
	mov byte [os_NetActivity_TX], 1
	bt ax, 7
	jc network_rx_as_well

network_end:
	mov al, 0x20			; Acknowledge the IRQ on the PIC(s)
	cmp byte [os_NetIRQ], 8
	jl network_ack_only_low		; If the network IRQ is less than 8 then the other PIC does not need to be ack'ed
	out 0xA0, al
network_ack_only_low:
	out 0x20, al

	popfq
	pop rax
	pop rcx
	pop rsi
	pop rdi
	iretq
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; Network interrupt callback.
align 8
network_callback:
	pushfq
	cld				; Clear direction flag
	call [os_NetworkCallback]
	popfq
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; Clock interrupt callback.
align 8
clock_callback:
	pushfq
	cld				; Clear direction flag
	call [os_ClockCallback]
	popfq
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; A simple interrupt that just acknowledges an IPI. Useful for getting an AP past a 'hlt' in the code.
align 8
ap_wakeup:
	push rdi
	push rax

	mov rdi, [os_LocalAPICAddress]	; Acknowledge the IPI
	add rdi, 0xB0
	xor eax, eax
	stosd

	pop rax
	pop rdi
	iretq				; Return from the IPI.
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; Resets a CPU to execute ap_clear
align 8
ap_reset:
	mov rax, ap_clear		; Set RAX to the address of ap_clear
	mov [rsp], rax			; Overwrite the return address on the CPU's stack
	mov rdi, [os_LocalAPICAddress]	; Acknowledge the IPI
	add rdi, 0xB0
	xor eax, eax
	stosd
	iretq				; Return from the IPI. CPU will execute code at ap_clear
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; CPU Exception Gates
align 8
exception_gate_00:
	mov [rsp-16], rax
	xor eax, eax
	mov [rsp-8], rax
	sub rsp, 16
	mov al, 0x00
	jmp exception_gate_main

align 8
exception_gate_01:
	mov [rsp-16], rax
	xor eax, eax
	mov [rsp-8], rax
	sub rsp, 16
	mov al, 0x01
	jmp exception_gate_main

align 8
exception_gate_02:
	mov [rsp-16], rax
	xor eax, eax
	mov [rsp-8], rax
	sub rsp, 16
	mov al, 0x02
	jmp exception_gate_main

align 8
exception_gate_03:
	mov [rsp-16], rax
	xor eax, eax
	mov [rsp-8], rax
	sub rsp, 16
	mov al, 0x03
	jmp exception_gate_main

align 8
exception_gate_04:
	mov [rsp-16], rax
	xor eax, eax
	mov [rsp-8], rax
	sub rsp, 16
	mov al, 0x04
	jmp exception_gate_main

align 8
exception_gate_05:
	mov [rsp-16], rax
	xor eax, eax
	mov [rsp-8], rax
	sub rsp, 16
	mov al, 0x05
	jmp exception_gate_main

align 8
exception_gate_06:
	mov [rsp-16], rax
	xor eax, eax
	mov [rsp-8], rax
	sub rsp, 16
	mov al, 0x06
	jmp exception_gate_main

align 8
exception_gate_07:
	mov [rsp-16], rax
	xor eax, eax
	mov [rsp-8], rax
	sub rsp, 16
	mov al, 0x07
	jmp exception_gate_main

align 8
exception_gate_08:
	push rax
	mov al, 0x08
	jmp exception_gate_main
	times 16 db 0x90

align 8
exception_gate_09:
	mov [rsp-16], rax
	xor eax, eax
	mov [rsp-8], rax
	sub rsp, 16
	mov al, 0x09
	jmp exception_gate_main

align 8
exception_gate_10:
	push rax
	mov al, 0x0A
	jmp exception_gate_main
	times 16 db 0x90

align 8
exception_gate_11:
	push rax
	mov al, 0x0B
	jmp exception_gate_main
	times 16 db 0x90

align 8
exception_gate_12:
	push rax
	mov al, 0x0C
	jmp exception_gate_main
	times 16 db 0x90

align 8
exception_gate_13:
	push rax
	mov al, 0x0D
	jmp exception_gate_main
	times 16 db 0x90

align 8
exception_gate_14:
	push rax
	mov al, 0x0E
	jmp exception_gate_main
	times 16 db 0x90

align 8
exception_gate_15:
	mov [rsp-16], rax
	xor eax, eax
	mov [rsp-8], rax
	sub rsp, 16
	mov al, 0x0F
	jmp exception_gate_main

align 8
exception_gate_16:
	mov [rsp-16], rax
	xor eax, eax
	mov [rsp-8], rax
	sub rsp, 16
	mov al, 0x10
	jmp exception_gate_main

align 8
exception_gate_17:
	push rax
	mov al, 0x11
	jmp exception_gate_main
	times 16 db 0x90

align 8
exception_gate_18:
	mov [rsp-16], rax
	xor eax, eax
	mov [rsp-8], rax
	sub rsp, 16
	mov al, 0x12
	jmp exception_gate_main

align 8
exception_gate_19:
	mov [rsp-16], rax
	xor eax, eax
	mov [rsp-8], rax
	sub rsp, 16
	mov al, 0x13
	jmp exception_gate_main

align 8
exception_gate_20:
	mov [rsp-16], rax
	xor eax, eax
	mov [rsp-8], rax
	sub rsp, 16
	mov al, 0x14
	jmp exception_gate_main

align 8
exception_gate_main:
	mov qword [os_NetworkCallback], 0	; Reset the network callback
	mov qword [os_ClockCallback], 0		; Reset the clock callback
	push rbx
	push rdi
	push rsi
	push rcx			; Char counter for b_output
	push rax			; Save RAX since b_smp_get_id clobbers it
	mov rsi, newline
	mov rcx, 1
	call b_output
	mov rsi, int_string00
	mov rcx, 24
	call b_output
	call b_smp_get_id		; Get the local CPU ID and print it
	call os_debug_dump_ax
	mov rsi, int_string01
	mov rcx, 13
	call b_output
	mov rsi, exc_string00
	pop rax
	and rax, 0x00000000000000FF	; Clear out everything in RAX except for AL
	push rax
	mov bl, 6			; Length of each message
	mul bl				; AX = AL x BL
	add rsi, rax			; Use the value in RAX as an offset to get to the right message
	pop rax
	mov bl, 0x0F
	mov rcx, 6
	call b_output
	pop rcx
	pop rsi
	pop rdi
	pop rbx
	pop rax
	mov rsi, int_string02
	mov rcx, 5
	call b_output
	mov rax, [rsp+8] 			; RIP of caller
	call os_debug_dump_rax
	mov rsi, newline
	mov rcx, 1
	call b_output
	jmp $				; For debugging
	jmp ap_clear			; jump to AP clear code


int_string00 db 'Fatal Exception - CPU 0x'
int_string01 db ' - Interrupt '
int_string02 db ' @ 0x'
; Strings for the error messages
exc_string db 'Unknown Fatal Exception!'
exc_string00 db '00(DE)'
exc_string01 db '01(DB)'
exc_string02 db '02    '
exc_string03 db '03(BP)'
exc_string04 db '04(OF)'
exc_string05 db '05(BR)'
exc_string06 db '06(UD)'
exc_string07 db '07(NM)'
exc_string08 db '08(DF)'
exc_string09 db '09    '	; No longer generated on new CPU's
exc_string10 db '10(TS)'
exc_string11 db '11(NP)'
exc_string12 db '12(SS)'
exc_string13 db '13(GP)'
exc_string14 db '14(PF)'
exc_string15 db '15    '
exc_string16 db '16(MF)'
exc_string17 db '17(AC)'
exc_string18 db '18(MC)'
exc_string19 db '19(XM)'
exc_string20 db '20(VE)'


; =============================================================================
; EOF
