; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; HPET Functions
; =============================================================================


; Note:	There are 1,000,000 microseconds in a second
;	There are 1,000 milliseconds in a second


; -----------------------------------------------------------------------------
; os_hpet_init -- Initialize the High Precision Event Timer
;  IN:	Nothing
; OUT:	Nothing
;	All other registers preserved
os_hpet_init:
	; Pure64 has already initialized the HPET (if it existed)

	; Verify there is a valid HPET address
	mov rax, [os_HPET_Address]
	jz os_hpet_init_error

	; Gather clock period
	mov ecx, HPET_GEN_CAP
	call os_hpet_read		; Get HPET General Capabilities and ID Register
	shr rax, 32			; Shift COUNTER_CLK_PERIOD (femtoseconds per tick) into EAX
	mov [os_HPET_Frequency], eax

	; Set flag that HPET was enabled
	or qword [os_SysConfEn], 1 << 4

os_hpet_init_error:
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_hpet_us -- Get current microseconds (us) since HPET started
; IN:	Nothing
; OUT:	RAX = Time in microseconds since start
os_hpet_us:
	push rdx
	push rcx

	xor edx, edx

	; Read Main Counter
	mov ecx, HPET_MAIN_COUNTER
	call os_hpet_read		; Read HPET Main Counter to RAX

	; Multiply by Main Counter Clock Period
	mov ecx, [os_HPET_Frequency]
	mul rcx				; RDX:RAX *= RCX

	; Divide by # of femtoseconds in a microsecond
	mov rcx, 1000000000
	div rcx				; RAX = RDX:RAX / RCX	

	pop rcx
	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_hpet_read -- Read from a register in the High Precision Event Timer
;  IN:	ECX = Register to read
; OUT:	RAX = Register value
;	All other registers preserved
os_hpet_read:
	mov rax, [os_HPET_Address]
	mov rax, [rax + rcx]
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_hpet_write -- Write to a register in the High Precision Event Timer
;  IN:	ECX = Register to write
;	RAX = Value to write
; OUT:	All registers preserved
os_hpet_write:
	push rcx
	add rcx, [os_HPET_Address]
	mov [rcx], rax
	pop rcx
	ret
; -----------------------------------------------------------------------------


; Register list (64-bits wide)
HPET_GEN_CAP		equ 0x000 ; COUNTER_CLK_PERIOD (63:32), LEG_RT_CAP (15), COUNT_SIZE_CAP (13), NUM_TIM_CAP (12:8)
; 0x008 - 0x00F are Reserved
HPET_GEN_CONF		equ 0x010 ; LEG_RT_CNF (1), ENABLE_CNF (0)
; 0x018 - 0x01F are Reserved
HPET_GEN_INT_STATUS	equ 0x020
; 0x028 - 0x0EF are Reserved
HPET_MAIN_COUNTER	equ 0x0F0
; 0x0F8 - 0x0FF are Reserved
HPET_TIMER_0_CONF	equ 0x100
HPET_TIMER_0_COMP	equ 0x108
HPET_TIMER_0_INT	equ 0x110
; 0x118 - 0x11F are Reserved
HPET_TIMER_1_CONF	equ 0x120
HPET_TIMER_1_COMP	equ 0x128
HPET_TIMER_1_INT	equ 0x130
; 0x138 - 0x13F are Reserved
HPET_TIMER_2_CONF	equ 0x140
HPET_TIMER_2_COMP	equ 0x148
HPET_TIMER_2_INT	equ 0x150
; 0x158 - 0x15F are Reserved
; 0x160 - 0x3FF are Reserved for Timers 3-31


; =============================================================================
; EOF