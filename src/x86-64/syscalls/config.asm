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
	call os_pci_read
	ret

b_system_config_pci_write:
        call os_pci_write
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
