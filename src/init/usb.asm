; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Initialize USB
; =============================================================================


; -----------------------------------------------------------------------------
; init_usb -- Configure the first USB Controller it finds
init_usb:
	; Check Bus Table for a USB Controller
	mov rsi, bus_table		; Load Bus Table address to RSI
	sub rsi, 16
	add rsi, 8			; Add offset to Class Code
init_usb_check_bus:
	add rsi, 16			; Increment to next record in memory
	mov ax, [rsi]			; Load Class Code / Subclass Code
	cmp ax, 0xFFFF			; Check if at end of list
	je init_usb_probe_not_found
	cmp ax, 0x0C03			; Serial Bus Controller (0C) / USB Controller (03)
	je init_usb_probe_find_driver
	jmp init_usb_check_bus		; Check Bus Table again

	; Check the USB Controller to see if it is supported
init_usb_probe_find_driver:
	sub rsi, 8			; Move RSI back to start of Bus record
	mov edx, [rsi]			; Load value for os_bus_read/write
	mov dl, 0x02
	call os_bus_read
	shr eax, 8			; Shift Program Interface to AL
	cmp al, 0x30			; PI for XHCI
	je init_usb_probe_found_xhci
	add rsi, 8
	jmp init_usb_check_bus

init_usb_probe_found_xhci:
	call xhci_init

init_usb_probe_not_found:

	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF