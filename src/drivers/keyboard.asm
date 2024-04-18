; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; Keyboard Functions
; =============================================================================


; -----------------------------------------------------------------------------
keyboard_init:
	mov dx, KEYBOARD_DATA
	in al, dx			; Read from Data Port

	call keyboard_wait

	mov dx, KEYBOARD_CS
	mov al, 0x20			; Command to Read "byte 0" from internal RAM
	out dx, al			; Send the command to the PS/2 controller

	call keyboard_wait
	
	mov dx, KEYBOARD_DATA		; Port where the result is
	in al, dx

	mov dx, KEYBOARD_CS
	mov al, 0x60			; Write next byte to "byte 0" of internal RAM
	out dx, al			; Send the command to the PS/2 controller

	call keyboard_wait

	mov dx, KEYBOARD_DATA
	mov al, 0x65			; TODO Don't use a fixed value here
	out dx, al
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; keyboard_wait - Wait for the PS/2 buffers to be empty
keyboard_wait:
	mov dx, KEYBOARD_DATA
	in al, dx			; Read from the keyboard
	mov dx, KEYBOARD_CS
	in al, dx			; Read Status Register
	bt ax, 0			; Check if Output buffer is full
	jc keyboard_wait
	bt ax, 1			; Check if Input buffer is full
	jc keyboard_wait
	ret
; -----------------------------------------------------------------------------


KEYBOARD_DATA:	equ 0x60 ; Read/Write Data Port
KEYBOARD_CS:	equ 0x64 ; Read Status Register / Write Command Register


; =============================================================================
; EOF