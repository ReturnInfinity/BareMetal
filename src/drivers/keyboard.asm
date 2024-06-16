; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; Keyboard Functions
; =============================================================================


; -----------------------------------------------------------------------------
keyboard_init:
	call ps2_flush			; Read any pending data

	; Disable keyboard
	mov al, PS2_COMMAND_DI_KBD
	call ps2_send_cmd
	
	; Disable AUX (if it exists)
	mov al, PS2_COMMAND_DI_AUX
	call ps2_send_cmd

	; Read Controller Configuration Byte
	mov al, PS2_COMMAND_RD_CCB	; Command to Read "byte 0" from internal RAM
	call ps2_send_cmd
	call ps2_read_data

	; Configure the values for the PS/2 controller
	mov bl, al			; Save the CCB to BL
	; Clear bit 1 for Second PS/2 port interrupt disabled
	; Clear bit 4 for First PS/2 port clock enabled
	; Set bit 0 for First PS/2 port interrupt enabled
	; Set bit 5 for Second PS/2 port clock disabled
	; Set bit 6 for First PS/2 port translation enabled
	and bl, 0b11101101		; Clear bits 1 and 4
	or bl, 0b01100001		; Set bits 0, 5, and 6

	; Write Controller Configuration Byte
	mov al, PS2_COMMAND_WR_CCB	; Write next byte to "byte 0" of internal RAM
	call ps2_send_cmd
	mov dx, PS2_DATA
	mov al, bl			; Moved the updated CCB to AL
	out dx, al

	; Enable keyboard
	mov al, PS2_COMMAND_EN_KBD
	call ps2_send_cmd

	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; ps2_read_data - Read data from PS/2 port when it is ready
ps2_read_data:
	push rdx
ps2_read_data_read:
	mov dx, PS2_CS
	in al, dx			; Read Status Register
	bt ax, 0			; Check if Output buffer is full
	jnc ps2_read_data_read
	mov dx, PS2_DATA
	in al, dx			; Read the data
	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; ps2_send_cmd - Send a single byte command to the PS/2 Controller
;  IN:	AL = Command to send
; OUT:	Nothing
ps2_send_cmd:
	push rdx
	call ps2_wait			; Wait if a command is still in process
	mov dx, PS2_CS
	out dx, al			; Send the command
	call ps2_wait			; Wait for the command to be completed
	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; ps2_wait - Wait for the PS/2 Controller input buffer to be empty
ps2_wait:
	push rdx
	push rax
ps2_wait_read:
	mov dx, PS2_CS
	in al, dx			; Read Status Register
	bt ax, 1			; Check if Input buffer is full
	jc ps2_wait_read
	pop rax
	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
ps2_flush:
	mov dx, PS2_DATA
	in al, dx			; Read a byte of data from output
	mov dx, PS2_CS
	in al, dx			; Read Status Register
	bt ax, PS2_STATUS_OUTPUT
	jc ps2_flush
	ret
; -----------------------------------------------------------------------------


PS2_DATA		equ 0x60 ; Read/Write Data Port
PS2_CS			equ 0x64 ; Read Status Register / Write Command Register

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
PS2_COMMAND_RD_CCB	equ 0x20 ; Read byte 0 of the PS/2 Controller Configuration Byte
PS2_COMMAND_WR_CCB	equ 0x60 ; Write byte 0 of the PS/2 Controller Configuration Byte
PS2_COMMAND_DI_AUX	equ 0xA7 ; Disable Auxiliary Device
PS2_COMMAND_EN_AUX	equ 0xA8 ; Enable Auxiliary Device
PS2_COMMAND_TEST	equ 0xAA ; Test PS/2 Controller
PS2_COMMAND_TEST_KBD	equ 0xAB ; Test first PS/2 port
PS2_COMMAND_DI_KBD	equ 0xAD ; Disable first PS/2 port
PS2_COMMAND_EN_KBD	equ 0xAE ; Enable first PS/2 port

; PS/2 Keyboard Commands
PS2_COMMAND_SET_LEDS	equ 0xED
PS2_COMMAND_SCANSET	equ 0xF0
PS2_COMMAND_RATE	equ 0xF3
PS2_COMMAND_ENABLE	equ 0xF4


; =============================================================================
; EOF