; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; PS/2 Keyboard Functions
; =============================================================================


; -----------------------------------------------------------------------------
ps2_init:
	call ps2_flush			; Read any pending data

	; Disable keyboard
	mov al, PS2_KBD_DIS
	call ps2_send_cmd

	; Disable AUX (if it exists)
	mov al, PS2_AUX_DIS
	call ps2_send_cmd

	; Execute a self-test on the PS/2 Controller
	call ps2_flush
	mov al, PS2_CTRL_TEST
	call ps2_send_cmd
	call ps2_read_data
	cmp al, 0x55			; 0x55 means test passed
	jne ps2_init_error		; Bail out otherwise

	; Read Controller Configuration Byte
	mov al, PS2_RD_CCB		; Command to Read "byte 0" from internal RAM
	call ps2_send_cmd
	call ps2_read_data

	; Configure the values for the PS/2 controller
	mov bl, al			; Save the CCB to BL
	; Clear bit 1 for Second PS/2 port interrupt disabled
	; Clear bit 4 for First PS/2 port clock enabled
	and bl, 0b11101101		; Clear bits 1 and 4
	; Set bit 0 for First PS/2 port interrupt enabled
	; Set bit 5 for Second PS/2 port clock disabled
	; Set bit 6 for First PS/2 port translation enabled
	or bl, 0b01100001		; Set bits 0, 5, and 6

	; Write Controller Configuration Byte
	mov al, PS2_WR_CCB		; Write next byte to "byte 0" of internal RAM
	call ps2_send_cmd
	mov al, bl			; Moved the updated CCB to AL
	out PS2_DATA, al

	; Enable keyboard
	mov al, PS2_KBD_EN
	call ps2_send_cmd

	; Set flag that the PS/2 keyboard was enabled
	or qword [os_SysConfEn], 1 << 0

ps2_init_error:
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; ps2_keyboard_interrupt - Converts scan code from keyboard to character
ps2_keyboard_interrupt:
	push rbx
	push rax

	xor eax, eax

	in al, PS2_DATA			; Get the scan code from the keyboard
	cmp al, 0x01
	je keyboard_escape
	cmp al, 0x1D
	je keyboard_control
	cmp al, 0x2A			; Left Shift Make
	je keyboard_shift
	cmp al, 0x36			; Right Shift Make
	je keyboard_shift
	cmp al, 0x9D
	je keyboard_nocontrol
	cmp al, 0xAA			; Left Shift Break
	je keyboard_noshift
	cmp al, 0xB6			; Right Shift Break
	je keyboard_noshift
	test al, 0x80
	jz keydown
	jmp keyup

keydown:
	cmp byte [key_shift], 0x00
	je keyboard_lowercase

keyboard_uppercase:
	mov rbx, keylayoutupper
	jmp keyboard_processkey

keyboard_lowercase:
	mov rbx, keylayoutlower

keyboard_processkey:			; Convert the scan code
	add rbx, rax
	mov bl, [rbx]
	mov [key], bl
	jmp keyboard_done

keyboard_escape:
	jmp reboot

keyup:
	jmp keyboard_done

keyboard_control:
	mov byte [key_control], 0x01
	jmp keyboard_done

keyboard_nocontrol:
	mov byte [key_control], 0x00
	jmp keyboard_done

keyboard_shift:
	mov byte [key_shift], 0x01
	jmp keyboard_done

keyboard_noshift:
	mov byte [key_shift], 0x00
	jmp keyboard_done

keyboard_done:
	pop rax
	pop rbx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; ps2_read_data - Read data from PS/2 port when it is ready
ps2_read_data:
	in al, PS2_STATUS		; Read Status Register
	bt ax, 0			; Check if Output buffer is full
	jnc ps2_read_data
	in al, PS2_DATA			; Read the data
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; ps2_send_cmd - Send a single byte command to the PS/2 Controller
;  IN:	AL = Command to send
; OUT:	Nothing
ps2_send_cmd:
	call ps2_wait			; Wait if a command is still in process
	out PS2_CMD, al			; Send the command
	call ps2_wait			; Wait for the command to be completed
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; ps2_wait - Wait for the PS/2 Controller input buffer to be empty
;  IN:	Nothing
; OUT:	Nothing
ps2_wait:
	push rax
ps2_wait_read:
	in al, PS2_STATUS		; Read Status Register
	bt ax, 1			; Check if Input buffer is full
	jc ps2_wait_read
	pop rax
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; ps2_flush - Flush pending data from PS/2 Controller
;  IN:	Nothing
; OUT:	Nothing
ps2_flush:
	in al, PS2_DATA			; Read a byte of data from controller
	in al, PS2_STATUS		; Read Status Register
	bt ax, PS2_STATUS_OUTPUT	; Check if Output buffer status is full
	jc ps2_flush			; If so, read a byte of data again
	ret
; -----------------------------------------------------------------------------


; PS/2 Ports
PS2_DATA		equ 0x60 ; Data Port - Read/Write
PS2_STATUS		equ 0x64 ; Status Register - Read
PS2_CMD			equ 0x64 ; Command Register - Write

; PS/2 Status Codes
PS2_STATUS_ACK		equ 0xFA
PS2_STATUS_RESEND	equ 0xFE
PS2_STATUS_ERROR	equ 0xFC

; PS/2 Status Bits
PS2_STATUS_OUTPUT	equ 0 ; Output buffer status (0 = empty, 1 = full)
PS2_STATUS_INPUT	equ 1 ; Input buffer status (0 = empty, 1 = full)
PS2_STATUS_FLAG		equ 2 ; System Flag. Should be set to 1 by system firmware
PS2_STATUS_COMMAND	equ 3 ; Command/data (0 = data written to input is for PS/2 device, 1 = data written to input is for PS/2 controller)
PS2_STATUS_BIT4		equ 4 ; ???
PS2_STATUS_BIT5		equ 5 ; ???
PS2_STATUS_TIMEOUT	equ 6 ; Time-out error (0 = no error, 1 = time-out error)
PS2_STATUS_PARITY	equ 7 ; Parity error (0 = no error, 1 = parity error)

; PS/2 Controller Configuration Bits
PS2_CCB_KBD_INT		equ 0 ; First PS/2 port interrupt (1 = enabled, 0 = disabled)
PS2_CCB_AUX_INT		equ 1 ; Second PS/2 port interrupt (1 = enabled, 0 = disabled, only if 2 PS/2 ports supported)
PS2_CCB_SYSFLAG		equ 2 ; System Flag (1 = system passed POST, 0 = your OS shouldn't be running)
PS2_CCB_BIT3		equ 3 ; ???
PS2_CCB_KBD_CLK		equ 4 ; First PS/2 port clock (1 = disabled, 0 = enabled)
PS2_CCB_AUX_CLK		equ 5 ; Second PS/2 port clock (1 = disabled, 0 = enabled, only if 2 PS/2 ports supported)
PS2_CCB_KBD_TRANS	equ 6 ; First PS/2 port translation (1 = enabled, 0 = disabled)
PS2_CCB_BIT7		equ 7 ; ???

; PS/2 Controller Commands
PS2_RD_CCB		equ 0x20 ; Read byte 0 of the PS/2 Controller Configuration Byte
PS2_WR_CCB		equ 0x60 ; Write byte 0 of the PS/2 Controller Configuration Byte
PS2_AUX_DIS		equ 0xA7 ; Disable Auxiliary Device
PS2_AUX_EN		equ 0xA8 ; Enable Auxiliary Device
PS2_CTRL_TEST		equ 0xAA ; Test PS/2 Controller
PS2_KBD_TEST		equ 0xAB ; Test first PS/2 port
PS2_KBD_DIS		equ 0xAD ; Disable first PS/2 port
PS2_KBD_EN		equ 0xAE ; Enable first PS/2 port
PS2_COMMAND_RESET_CPU	equ 0xFE ; Reset the CPU

; PS/2 Keyboard Commands
PS2_KBD_SET_LEDS	equ 0xED
PS2_KBD_SCANSET		equ 0xF0
PS2_KBD_RATE		equ 0xF3
PS2_KBD_ENABLE		equ 0xF4

; PS/2 Mouse Commands
PS2_SETSCALING1TO1	equ 0xE6
PS2_SETSCALING2TO1	equ 0xE7
PS2_SETRESOLUTION	equ 0xE8
PS2_SETSAMPLERATE	equ 0xF3
PS2_ENABLEPACKETSTREAM	equ 0xF4
PS2_DISABLEPACKETSTREAM	equ 0xF5
PS2_SETDEFAULTS		equ 0xF6 ; Disables streaming, sets the packet rate to 100 per second, and resolution to 4 pixels per mm.


; =============================================================================
; EOF
