; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2026 Return Infinity -- see LICENSE.TXT
;
; Initialize HID
; =============================================================================


; -----------------------------------------------------------------------------
init_hid:
	; Output progress via serial
	mov esi, msg_hid
	call os_debug_string

	; Configure the PS/2 keyboard and mouse (if they exist)
	call ps2_init

init_hid_done:

%ifndef NO_LFB
	; Output block to screen (7/8)
	mov ebx, 12
	call os_debug_block
%endif

	; Output progress via serial
	mov esi, msg_ok
	call os_debug_string

	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
