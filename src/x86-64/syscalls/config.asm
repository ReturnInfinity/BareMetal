; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2017 Return Infinity -- see LICENSE.TXT
;
; Config Functions
; =============================================================================


; -----------------------------------------------------------------------------
; b_system_config - View or modify system configuration options
; IN:	RDX = Function #
;	RAX = Variable
; OUT:	RAX = Result
;	All other registers preserved
b_system_config:
       cmp rdx, 0
       je b_system_config_timecounter
       cmp rdx, 3
       je b_system_config_networkcallback_get
       cmp rdx, 4
       je b_system_config_networkcallback_set
       cmp rdx, 5
       je b_system_config_clockcallback_get
       cmp rdx, 6
       je b_system_config_clockcallback_set
       cmp rdx, 30
       je b_system_config_mac
       ; PCI
       cmp rdx, 0x40
       je b_system_config_pci_read
       cmp rdx, 0x41
       je b_system_config_pci_write
       ret

b_system_config_timecounter:
       mov rax, [os_ClockCounter]	; Grab the timer counter value. It increments 8 times a second
       ret

b_system_config_networkcallback_get:
       mov rax, [os_NetworkCallback]
       ret

b_system_config_networkcallback_set:
       mov qword [os_NetworkCallback], rax
       ret

b_system_config_clockcallback_get:
       mov rax, [os_ClockCallback]
       ret

b_system_config_clockcallback_set:
       mov qword [os_ClockCallback], rax
       ret

b_system_config_mac:
       call b_net_status
       ret

b_system_config_pci_read:
	; PCI Bus, Device/Function, and Register are packed into RAX as such:
	; 0x 00 00 00 00 00 BS DF RG
	; BS = Bus, 8 bits
	; DF = Device/Function, 8 bits
	; RG = Register, 8 bits, 6 used, upper 2 bits will be cleared if set
	push rbx
	push rcx
	push rdx

	and eax, 0x00FFFFFF		; Clear bits 63 - 24
	mov rdx, rax
	mov rcx, rax
	mov rbx, rax

	and edx, 0x0000003F		; Clear bits 63 - 6

	shr ecx, 8
	and ecx, 0x000000FF		; Clear bits 63 - 8

	shr ebx, 16

	call os_pci_read

	pop rdx
	pop rcx
	pop rbx
	ret

b_system_config_pci_write:
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
