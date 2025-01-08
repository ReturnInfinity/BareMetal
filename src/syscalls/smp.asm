; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; SMP Functions
; =============================================================================


; -----------------------------------------------------------------------------
; b_smp_reset -- Resets a CPU Core
;  IN:	AL = CPU #
; OUT:	Nothing. All registers preserved.
; Note:	This code resets an AP for set-up use only.
b_smp_reset:
	push rcx
	push rax

	cli
b_smp_reset_wait:
	mov ecx, APIC_ICRL
	call os_apic_read
	bt eax, 12		; Check if Delivery Status is 0 (Idle)
	jc b_smp_reset_wait	; If not, wait - a send is already pending
	mov rax, [rsp]		; Retrieve CPU APIC # from the stack
	mov ecx, APIC_ICRH
	shl eax, 24		; AL holds the CPU APIC #, shift left 24 bits to get it into 31:24, 23:0 are reserved
	call os_apic_write	; Write to the high bits first
	mov ecx, APIC_ICRL
	xor eax, eax		; Clear EAX, namely bits 31:24
	mov al, 0x81		; Execute interrupt 0x81
	call os_apic_write	; Then write to the low bits
	sti

	pop rax
	pop rcx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_wakeup -- Wake up a CPU Core
;  IN:	AL = CPU #
; OUT:	Nothing. All registers preserved.
b_smp_wakeup:
	push rcx
	push rax

	cli
b_smp_wakeup_wait:
	mov ecx, APIC_ICRL
	call os_apic_read
	bt eax, 12		; Check if Delivery Status is 0 (Idle)
	jc b_smp_wakeup_wait	; If not, wait - a send is already pending
	mov rax, [rsp]		; Retrieve CPU APIC # from the stack
	mov ecx, APIC_ICRH
	shl eax, 24		; AL holds the CPU APIC #, shift left 24 bits to get it into 31:24, 23:0 are reserved
	call os_apic_write	; Write to the high bits first
	mov ecx, APIC_ICRL
	xor eax, eax		; Clear EAX, namely bits 31:24
	mov al, 0x80		; Execute interrupt 0x81
	call os_apic_write	; Then write to the low bits
	sti

	pop rax
	pop rcx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_wakeup_all -- Wake up all CPU Cores
;  IN:	Nothing.
; OUT:	Nothing. All registers preserved.
b_smp_wakeup_all:
	push rcx
	push rax

	cli
b_smp_wakeup_all_wait:
	mov ecx, APIC_ICRL
	call os_apic_read
	bt eax, 12		; Check if Delivery Status is 0 (Idle)
	jc b_smp_wakeup_all_wait	; If not, wait - a send is already pending
	mov ecx, APIC_ICRH
	xor eax, eax
	call os_apic_write	; Write to the high bits first
	mov ecx, APIC_ICRL
	mov eax, 0x000C0080	; Execute interrupt 0x80 on All Excluding Self (0xC)
	call os_apic_write	; Then write to the low bits
	sti

	pop rax
	pop rcx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_get_id -- Returns the APIC ID of the CPU that ran this function
;  IN:	Nothing
; OUT:	RAX = CPU's APIC ID number, All other registers preserved.
b_smp_get_id:
	push rcx

	mov ecx, APIC_ID
	call os_apic_read	; Write to the high bits first
	shr rax, 24		; AL now holds the CPU's APIC ID (0 - 255)

	pop rcx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_set -- Set a specific CPU to run code
;  IN:	RAX = Code address
;	RCX = CPU APIC ID
; OUT:	RAX = 0 on error
; Note:	Code address must be 16-byte aligned
b_smp_set:
	push rdi
	push rax
	push rcx		; Save the APIC ID
	push rax		; Save the code address

	mov rdi, os_SMP
	shl rcx, 3		; Quick multiply by 8
	add rdi, rcx		; Add the offset
	mov rcx, [rdi]		; Load current value for that core

	bt cx, 0		; Check for "present" flag
	jnc b_smp_set_error	; Bail out if 0

	and cl, 0xF0		; Clear the flags from the value in table
	cmp rcx, 0		; Is there already a code address set?
	jne b_smp_set_error	; Bail out if the core is already set

	and al, 0x0F		; Keep only the lower 4 bits
	cmp al, 0		; Are the lower 4 bits of the code address set to 0?
	jne b_smp_set_error	; Bail out if not as the code address isn't properly aligned

	pop rax			; Restore the code address
	or al, 0x01		; Make sure the present flag is set
	mov [rdi], rax		; Store code address

	pop rcx			; Restore the APIC ID
	xchg rax, rcx
	call b_smp_wakeup	; Wake up the core
	xchg rax, rcx

	pop rax
	pop rdi
	ret

b_smp_set_error:
	pop rax
	xor eax, eax		; Return 0 for error
	pop rcx
	pop rax
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_get -- Returns a CPU code address and flags
;  IN:	Nothing
; OUT:	RAX = Code address (bits 63:4) and flags (bits 3:0)
b_smp_get:
	push rsi

	call b_smp_get_id	; Return APIC ID in RAX

	mov rsi, os_SMP
	shl rax, 3		; Quick multiply by 8
	add rsi, rax		; Add the offset
	mov rax, [rsi]		; Load code address and flags
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_setflag -- Set a CPU flag
;  IN:	RCX = Flag #
; OUT:	Nothing
b_smp_setflag:
	push rsi
	push rax

	cmp rcx, 4		; If a value higher than 3 was chosen then bail out
	jge b_smp_setflag_done

	call b_smp_get_id	; Return APIC ID in RAX

	mov rsi, os_SMP
	shl rax, 3		; Quick multiply by 8
	add rsi, rax		; Add the offset
	mov rax, [rsi]		; Load code address and flags
	bts rax, rcx		; Set the flag
	mov [rsi], rax		; Store the code address and new flags

b_smp_setflag_done:
	pop rax
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_busy -- Check if CPU cores are busy
;  IN:	Nothing
; OUT:	RAX = 1 if CPU cores are busy, 0 if not.
;	All other registers preserved.
; Note:	This ignores the core it is running on
b_smp_busy:
	push rsi
	push rcx
	push rbx

	call b_smp_get_id
	mov bl, al		; Store local APIC ID in BL
	xor ecx, ecx
	mov rsi, os_SMP

b_smp_busy_read:
	lodsq			; Load a single CPU entry. Flags are in AL
	cmp bl, cl		; Compare entry to local APIC ID
	je b_smp_busy_skip	; Skip the entry for the current CPU
	inc cx
	cmp al, 0x01		; Bit 0 (Present) can be 0 or 1
	jg b_smp_busy_yes
	cmp cx, 0x100		; Only read up to 256 CPU cores
	jne b_smp_busy_read

b_smp_busy_no:
	xor eax, eax
	jmp b_smp_busy_end

b_smp_busy_skip:
	inc cx
	jmp b_smp_busy_read

b_smp_busy_yes:
	mov eax, 1

b_smp_busy_end:
	pop rbx
	pop rcx
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
