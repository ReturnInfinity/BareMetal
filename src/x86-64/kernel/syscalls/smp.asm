; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2016 Return Infinity -- see LICENSE.TXT
;
; SMP Functions
; =============================================================================


; -----------------------------------------------------------------------------
; b_smp_reset -- Resets a CPU Core
;  IN:	AL = CPU #
; OUT:	Nothing. All registers preserved.
; Note:	This code resets an AP
;	For set-up use only.
b_smp_reset:
	push rdi
	push rax

	mov edi, 0x0300
	add rdi, [os_LocalAPICAddress]
	shl eax, 24		; AL holds the CPU #, shift left 24 bits to get it into 31:24, 23:0 are reserved
	mov [rdi+0x10], eax	; Write to the high bits first
	xor eax, eax		; Clear EAX, namely bits 31:24
	mov al, 0x81		; Execute interrupt 0x81
	mov [rdi], eax		; Then write to the low bits

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

	mov edi, 0x0300
	add rdi, [os_LocalAPICAddress]
	shl eax, 24		; AL holds the CPU #, shift left 24 bits to get it into 31:24, 23:0 are reserved
	mov [rdi+0x10], eax	; Write to the high bits first
	xor eax, eax		; Clear EAX, namely bits 31:24
	mov al, 0x80		; Execute interrupt 0x80
	mov [rdi], eax		; Then write to the low bits

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
	
	mov edi, 0x0310
	add rdi, [os_LocalAPICAddress]
	xor eax, eax
	mov [rdi+0x10], eax	; Write to the high bits first
	mov eax, 0x000C0080	; Execute interrupt 0x80
	mov [rdi], eax	; Then write to the low bits

	pop rax
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_get_id -- Returns the APIC ID of the CPU that ran this function
;  IN:	Nothing
; OUT:	RAX = CPU's APIC ID number, All other registers preserved.
b_smp_get_id:
	mov rax, [os_LocalAPICAddress]
	mov eax, [rax+0x20]	; Add the offset for the APIC ID location
				; APIC ID is stored in bits 31:24
	shr eax, 24		; AL now holds the CPU's APIC ID (0 - 255)
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_enqueue -- Add a workload to the processing queue
;  IN:	RAX = Address of code to execute
;	RSI = Variable
; OUT:	Nothing
b_smp_enqueue:
	push rdi
	push rsi
	push rcx
	push rax

b_smp_enqueue_spin:
	bt word [os_QueueLock], 0	; Check if the mutex is free
	jc b_smp_enqueue_spin		; If not check it again
	lock bts word [os_QueueLock], 0	; The mutex was free, lock the bus. Try to grab the mutex
	jc b_smp_enqueue_spin		; Jump if we were unsuccessful

	cmp word [os_QueueLen], 256	; aka cpuqueuemax
	je b_smp_enqueue_fail

	mov edi, cpuqueue
	movzx ecx, word [cpuqueuefinish]
	shl ecx, 4			; Quickly multiply RCX by 16
	add rdi, rcx

	stosq				; Store the code address from RAX
	mov rax, rsi
	stosq				; Store the variable

	add word [os_QueueLen], 1
	movxz ebx, word [cpuqueuemax]
	xor edi, edi
	shr ecx, 4			; Quickly divide RCX by 16
	add ecx, 1
	cmp ecx, ebx
	cmove ecx, edi			; We wrap around

b_smp_enqueue_end:
	mov [cpuqueuefinish], ecx
	pop rax
	pop rcx
	pop rsi
	pop rdi
	btr word [os_QueueLock], 0	; Release the lock
	call b_smp_wakeup_all
	clc				; Carry clear for success
	ret

b_smp_enqueue_fail:
	pop rax
	pop rcx
	pop rsi
	pop rdi
	btr word [os_QueueLock], 0	; Release the lock
	stc				; Carry set for failure (Queue full)
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_dequeue -- Dequeue a workload from the processing queue
;  IN:	Nothing
; OUT:	RAX = Address of code to execute (Set to 0 if queue is empty)
;	RDI = Variable
b_smp_dequeue:
	push rsi
	push rcx

b_smp_dequeue_spin:
	bt word [os_QueueLock], 0	; Check if the mutex is free
	jc b_smp_dequeue_spin		; If not check it again
	lock bts word [os_QueueLock], 0	; The mutex was free, lock the bus. Try to grab the mutex
	jc b_smp_dequeue_spin		; Jump if we were unsuccessful

	cmp word [os_QueueLen], 0
	je b_smp_dequeue_fail

	mov esi, cpuqueue
	movzx ecx, word [cpuqueuestart]
	shl ecx, 4			; Quickly multiply RCX by 16
	add rsi, rcx

	lodsq				; Load the code address into RAX
	mov r9, rax
	lodsq				; Load the variable
	mov rdi, rax
	mov rax, r9

	sub word [os_QueueLen], 1
	movzx esi, word [cpuqueuemax]
	xor eax, eax
	shr ecx, 4			; Quickly divide RCX by 16
	add ecx, 1
	cmp ecx, esi
	cmove ecx, eax			; We wrap around

b_smp_dequeue_end:
	mov word [cpuqueuestart], cx
	pop rcx
	pop rsi
	btr word [os_QueueLock], 0	; Release the lock
	clc				; If we got here then ok
	ret

b_smp_dequeue_fail:
	xor eax, eax
	pop rcx
	pop rsi
	btr word [os_QueueLock], 0	; Release the lock
	stc
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_run -- Call the code address stored in RAX
;  IN:	RAX = Address of code to execute
; OUT:	Nothing
b_smp_run:
	call rax			; Run the code
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_queuelen -- Returns the number of items in the processing queue
;  IN:	Nothing
; OUT:	RAX = number of items in processing queue
b_smp_queuelen:
	movzx eax, word [os_QueueLen]
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_numcores -- Returns the number of cores in this computer
;  IN:	Nothing
; OUT:	RAX = number of cores in this computer
b_smp_numcores:
	movzx eax, word [os_NumCores]
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; b_smp_wait -- Wait until all other CPU Cores are finished processing
;  IN:	Nothing
; OUT:	Nothing. All registers preserved.
b_smp_wait:
	push rsi
	push rcx
	push rbx
	push rax

	call b_smp_get_id
	mov ebx, eax

	xor eax, eax
	xor ecx, ecx
	mov rsi, cpustatus

checkit:
	lodsb
	cmp ebx, ecx		; Check to see if it is looking at itself
	je skipit		; If so then skip as it should be marked as busy
	bt eax, 0		; Check the Present bit
	jnc skipit		; If carry is not set then the CPU does not exist
	bt eax, 1		; Check the Ready/Busy bit
	jnc skipit		; If carry is not set then the CPU is Ready
	sub rsi, 1
	jmp checkit		; Core is marked as Busy, check it again
skipit:
	add ecx, 1
	cmp ecx, 256
	jne checkit

	pop rax
	pop rbx
	pop rcx
	pop rsi
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
