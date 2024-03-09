; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; Config Functions
; =============================================================================


; -----------------------------------------------------------------------------
; b_config - View or modify system configuration options
; IN:	RCX = Function
;	RAX = Variable 1
;	RDX = Variable 2
; OUT:	RAX = Result
;	All other registers preserved
b_config:
	cmp rcx, 0x00
	je b_config_timecounter
	cmp rcx, 0x01
	je b_config_smp_get_id
	cmp rcx, 0x03
	je b_config_networkcallback_get
	cmp rcx, 0x04
	je b_config_networkcallback_set
	cmp rcx, 0x05
	je b_config_clockcallback_get
	cmp rcx, 0x06
	je b_config_clockcallback_set

; Video
	cmp rcx, 0x20
	je b_config_screen_lfb_get
	cmp rcx, 0x21
	je b_config_screen_x_get
	cmp rcx, 0x22
	je b_config_screen_y_get
	cmp rcx, 0x23
	je b_config_screen_bpp_get

; Network
	cmp rcx, 0x30
	je b_config_mac_get

; PCI
	cmp rcx, 0x40
	je b_config_pci_read
	cmp rcx, 0x41
	je b_config_pci_write

; Standard Output
	cmp rcx, 0x42
	je b_config_stdout_set
	cmp rcx, 0x43
	je b_config_stdout_get
	cmp rcx, 0x50
	je b_config_drive_id
	ret

b_config_timecounter:
	mov rax, [os_ClockCounter]	; Grab the timer counter value. It increments 8 times a second
	ret

b_config_smp_get_id:
	call b_smp_get_id
	ret

b_config_networkcallback_get:
	mov rax, [os_NetworkCallback]
	ret

b_config_networkcallback_set:
	mov qword [os_NetworkCallback], rax
	ret

b_config_clockcallback_get:
	mov rax, [os_ClockCallback]
	ret

b_config_clockcallback_set:
	mov qword [os_ClockCallback], rax
	ret

; Video

b_config_screen_lfb_get:
	mov rax, [os_screen_lfb]
	ret

b_config_screen_x_get:
	xor eax, eax
	mov ax, [os_screen_x]
	ret

b_config_screen_y_get:
	xor eax, eax
	mov ax, [os_screen_y]
	ret

b_config_screen_bpp_get:
	xor eax, eax
	mov al, [os_screen_bpp]
	ret

; Network

b_config_mac_get:
	call b_net_status
	ret

; Bus

b_config_pci_read:
	call os_bus_read
	ret

b_config_pci_write:
	call os_bus_write
	ret

b_config_stdout_get:
	mov rax, qword [0x100018]
	ret

b_config_stdout_set:
	mov qword [0x100018], rax
	ret

b_config_drive_id:
	push rdi
	mov rdi, rax
	call ahci_id
	pop rdi
	ret

; -----------------------------------------------------------------------------


; =============================================================================
; EOF
