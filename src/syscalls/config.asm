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
	cmp rcx, 0xFF
	jg b_config_end

; Basic
	cmp cl, 0x00
	je b_config_timecounter
	cmp cl, 0x01
	je b_config_smp_get_id
;	cmp cl, 0x02
;	je b_config_free_memory

; Video
	cmp cl, 0x20
	je b_config_screen_lfb_get
	cmp cl, 0x21
	je b_config_screen_x_get
	cmp cl, 0x22
	je b_config_screen_y_get
	cmp cl, 0x23
	je b_config_screen_ppsl_get
	cmp cl, 0x24
	je b_config_screen_bpp_get

; Network
	cmp cl, 0x30
	je b_config_mac_get

; PCI
	cmp cl, 0x40
	je b_config_pci_read
	cmp cl, 0x41
	je b_config_pci_write

; Standard Output
	cmp cl, 0x42
	je b_config_stdout_set
	cmp cl, 0x43
	je b_config_stdout_get

; Misc
	cmp cl, 0x50
	je b_config_drive_id

; End of options
b_config_end:
	ret

; Basic

b_config_timecounter:
	push rcx
	mov ecx, 0xF0
	call os_hpet_read
	pop rcx
	ret

b_config_smp_get_id:
	call b_smp_get_id
	ret

b_config_free_memory:
	mov eax, [os_MemAmount]
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

b_config_screen_ppsl_get:
	mov eax, [os_screen_ppsl]
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

; Standard Output

b_config_stdout_get:
	mov rax, qword [0x100018]
	ret

b_config_stdout_set:
	mov qword [0x100018], rax
	ret

; Misc

b_config_drive_id:
	push rdi
	mov rdi, rax
	call ahci_id
	pop rdi
	ret

; -----------------------------------------------------------------------------


; =============================================================================
; EOF
