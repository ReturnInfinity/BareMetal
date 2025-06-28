; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Initialize HID
; =============================================================================


; -----------------------------------------------------------------------------
init_hid:
	; Configure the PS/2 keyboard and mouse (if they exist)
	call ps2_init

	; Enumerate USB devices
	bt qword [os_SysConfEn], 5
	jnc init_hid_done
	sti
	call xhci_enumerate_devices
	cli

init_hid_done:
	; Output block to screen (7/8)
	mov ebx, 12
	call os_debug_block
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
