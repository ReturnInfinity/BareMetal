; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2017 Return Infinity -- see LICENSE.TXT
;
; SMP Functions
; =============================================================================


; -----------------------------------------------------------------------------
; b_smp_reset -- Resets a CPU Core
;  IN:	AL = CPU #
; OUT:	Nothing. All registers preserved.
; Note:	This code resets an AP for set-up use only.
b_smp_reset:
	push rdi
	push rax

	mov rdi, [os_LocalAPICAddress]
	shl eax, 24		; AL holds the CPU #, shift left 24 bits to get it into 31:24, 23:0 are reserved
	mov [rdi+0x0310], eax	; Write to the high bits first
	xor eax, eax		; Clear EAX, namely bits 31:24
	mov al, 0x81		; Execute interrupt 0x81
	mov [rdi+0x0300], eax	; Then write to the low bits

	pop rax
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_wakeup -- Wake up a CPU Core
;  IN:	AL = CPU #
; OUT:	Nothing. All registers preserved.
b_smp_wakeup:
	push rdi
	push rax

	mov rdi, [os_LocalAPICAddress]
	shl eax, 24		; AL holds the CPU #, shift left 24 bits to get it into 31:24, 23:0 are reserved
	mov [rdi+0x0310], eax	; Write to the high bits first
	xor eax, eax		; Clear EAX, namely bits 31:24
	mov al, 0x80		; Execute interrupt 0x80
	mov [rdi+0x0300], eax	; Then write to the low bits

	pop rax
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_wakeup_all -- Wake up all CPU Cores
;  IN:	Nothing.
; OUT:	Nothing. All registers preserved.
b_smp_wakeup_all:
	push rdi
	push rax

	mov rdi, [os_LocalAPICAddress]
	xor eax, eax
	mov [rdi+0x0310], eax	; Write to the high bits first
	mov eax, 0x000C0080	; Execute interrupt 0x80
	mov [rdi+0x0300], eax	; Then write to the low bits

	pop rax
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_get_id -- Returns the APIC ID of the CPU that ran this function
;  IN:	Nothing
; OUT:	RAX = CPU's APIC ID number, All other registers preserved.
b_smp_get_id:
	push rsi

	xor eax, eax
	mov rsi, [os_LocalAPICAddress]
	add rsi, 0x20		; Add the offset for the APIC ID location
	lodsd			; APIC ID is stored in bits 31:24
	shr rax, 24		; AL now holds the CPU's APIC ID (0 - 255)

	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_set -- Set a specific CPU to run code
;  IN:	RAX = Code address
;	RDX = Data address
;	RCX = CPU APIC ID
; OUT:	RAX = 0 on error
b_smp_set:
	push rdi
	push rcx

	mov rdi, os_cpu_work_table
	shl rcx, 4		; Quick multiply by 16
	add rdi, rcx		; Add the offset

	mov rcx, [rdi]		; Load current code address for that core
	cmp rcx, 0
	jne b_smp_set_error	; Bail out if the core is already set

	stosq			; Store code address
	xchg rax, rdx
	stosq			; Store data address
	xchg rax, rdx
	pop rcx			; Restore the APIC ID
	call b_smp_wakeup	; Wake up the core

	pop rdi
	ret

b_smp_set_error:
	xor eax, eax		; Return 0 for error
	pop rcx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_get_work -- Returns a workload from the work table
;  IN:	Nothing
; OUT:	RAX = Code addresss
;	RDX = Variable address
b_smp_get_work:
	push rsi

	call b_smp_get_id	; Return APIC ID in RAX

	mov rsi, os_cpu_work_table
	shl rax, 4		; Quick multiply by 16
	add rsi, rax		; Add the offset
	lodsq			; load code address
	xchg rax, rdx
	lodsq			; load data address
	xchg rax, rdx

	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_config -- Just a stub for now
;  IN:	Nothing
; OUT:	Nothing. All registers preserved.
b_smp_config:
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_lock -- Attempt to lock a mutex
;  IN:	RAX = Address of lock variable
; OUT:	Nothing. All registers preserved.
b_smp_lock:
	bt word [rax], 0	; Check if the mutex is free (Bit 0 cleared to 0)
	jc b_smp_lock		; If not check it again
	lock bts word [rax], 0	; The mutex was free, lock the bus. Try to grab the mutex
	jc b_smp_lock		; Jump if we were unsuccessful
	ret			; Lock acquired. Return to the caller
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_unlock -- Unlock a mutex
;  IN:	RAX = Address of lock variable
; OUT:	Nothing. All registers preserved.
b_smp_unlock:
	btr word [rax], 0	; Release the lock (Bit 0 cleared to 0)
	ret			; Lock released. Return to the caller
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
