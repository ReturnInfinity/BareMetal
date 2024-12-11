; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; PS/2 Functions
; =============================================================================


; -----------------------------------------------------------------------------
ps2_init:
	call ps2_flush			; Read any pending data

	; Disable keyboard
	mov al, PS2_COMMAND_KBD_DIS
	call ps2_send_cmd

	; Disable AUX (if it exists)
	mov al, PS2_COMMAND_AUX_DIS
	call ps2_send_cmd

	; Execute a self-test on the PS/2 Controller
	call ps2_flush
	mov al, PS2_COMMAND_CTRL_TEST
	call ps2_send_cmd
	call ps2_read_data
	cmp al, 0x55			; 0x55 means test passed
	jne ps2_init_error		; Bail out otherwise

	; Read Controller Configuration Byte
	mov al, PS2_COMMAND_RD_CCB	; Command to Read "byte 0" from internal RAM
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
	mov al, PS2_COMMAND_WR_CCB	; Write next byte to "byte 0" of internal RAM
	call ps2_send_cmd
	mov dx, PS2_DATA
	mov al, bl			; Moved the updated CCB to AL
	out dx, al

	; Enable keyboard
	mov al, PS2_COMMAND_KBD_EN
	call ps2_send_cmd

	; Enable mouse
	mov al, PS2_COMMAND_AUX_EN
	call ps2_send_cmd

	; Init keyboard

	; Test keyboard
;	mov al, PS2_COMMAND_KBD_TEST
;	call ps2_send_cmd
;	call ps2_read_data

	; Init mouse

	; Test mouse
;	mov al, PS2_COMMAND_AUX_TEST
;	call ps2_send_cmd
;	call ps2_read_data

	call mouse_init

	; Set flag that the PS/2 keyboard was enabled
	or qword [os_SysConfEn], 1 << 0

ps2_init_error:
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; ps2_read_data - Read data from PS/2 port when it is ready
ps2_read_data:
	push rdx
ps2_read_data_read:
	mov dx, PS2_STATUS
	in al, dx			; Read Status Register
	bt ax, PS2_STATUS_OUTPUT	; Check if Output buffer is full
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
	mov dx, PS2_CMD
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
	mov dx, PS2_STATUS
	in al, dx			; Read Status Register
	and al, PS2_STATUS_OUTPUT && PS2_STATUS_INPUT
	jnz ps2_wait_read
	pop rax
	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
ps2_flush:
	mov dx, PS2_DATA
	in al, dx			; Read a byte of data from output
	mov dx, PS2_STATUS
	in al, dx			; Read Status Register
	bt ax, PS2_STATUS_OUTPUT
	jc ps2_flush
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
;dl=1 read, dl=2 write
ps2wait:
	mov ecx, 1000
ps2wait_loop:
	in al, PS2_STATUS
	and al, dl
	jnz ps2wait_done
	dec ecx
	jnz ps2wait_loop
ps2wait_done:
	ret

ps2wr:
	mov dh, al
	mov dl, 2
	call ps2wait
	mov al, PS2_COMMAND_AUX_WRITE
	out PS2_CMD, al
	call ps2wait
	mov al, dh
	out PS2_DATA, al
	;no ret, fall into read code to read ack
ps2rd:
	mov dl, 1
	call ps2wait
	in al, PS2_DATA
	ret

;variables
packetsize: db 0
resolution: db 3
samplerate: db 200

mouse_init:
;initialize legacy ps2 user input
	xor rax, rax
	mov dl, 2
	call ps2wait
	mov al, PS2_COMMAND_AUX_EN
	out PS2_CMD, al
	;get ack
	call ps2rd
	;some compaq voodoo magic to enable irq12
	mov dl, 2
	call ps2wait
	mov al, PS2_COMMAND_RD_CCB
	out PS2_CMD, al
	mov dl, 1
	call ps2wait
	in al, PS2_DATA
	bts ax, 1
	btr ax, 5
	mov bl, al
	mov dl, 2
	call ps2wait
	mov al, PS2_COMMAND_WR_CCB
	out PS2_CMD, al
	call ps2wait
	mov al, bl
	out PS2_DATA, al
	;get optional ack
	mov dl, 1
	call ps2wait

	;restore to defaults
	mov al, 0F6h
	call ps2wr
	;enable Z axis
	mov al, 0F3h
	call ps2wr
	mov al, 200
	call ps2wr
	mov al, 0F3h
	call ps2wr
	mov al, 100
	call ps2wr
	mov al, 0F3h
	call ps2wr
	mov al, 80
	call ps2wr
	mov al, 0F2h
	call ps2wr
	call ps2rd
	mov byte [packetsize], 3
	or al, al
	jz .noZaxis
	mov byte [packetsize], 4
.noZaxis:	;enable 4th and 5th buttons
	mov al, 0F3h
	call ps2wr
	mov al, 200
	call ps2wr
	mov al, 0F3h
	call ps2wr
	mov al, 200
	call ps2wr
	mov al, 0F3h
	call ps2wr
	mov al, 80
	call ps2wr
	mov al, 0F2h
	call ps2wr
	call ps2rd

	;set sample rate
	mov al, 0F3h
	call ps2wr
	mov al, byte [samplerate]
	call ps2wr
	;set resolution
	mov al, 0E8h
	call ps2wr
	mov al, byte [resolution]
	call ps2wr
	;set scaling 1:1
	mov al, 0E6h
	call ps2wr
	;enable
	mov al, 0F4h
	call ps2wr

	;reset variables
	xor eax, eax
	mov dword [cnt], eax
	mov dword [x], eax
	mov dword [y], eax
	mov dword [z], eax
	ret
; -----------------------------------------------------------------------------


; PS/2 Ports
PS2_DATA		equ 0x60 ; Read/Write Data Port
PS2_STATUS		equ 0x64 ; Read Status Register
PS2_CMD			equ 0x64 ; Write Command Register

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
PS2_COMMAND_RD_CCB	equ 0x20 ; Read byte 0 of the PS/2 Controller Configuration Byte
PS2_COMMAND_WR_CCB	equ 0x60 ; Write byte 0 of the PS/2 Controller Configuration Byte
PS2_COMMAND_AUX_DIS	equ 0xA7 ; Disable Auxiliary Device
PS2_COMMAND_AUX_EN	equ 0xA8 ; Enable Auxiliary Device
PS2_COMMAND_AUX_TEST	equ 0xA9 ; Test Auxiliary Device
PS2_COMMAND_CTRL_TEST	equ 0xAA ; Test PS/2 Controller
PS2_COMMAND_KBD_TEST	equ 0xAB ; Test Keyboard
PS2_COMMAND_KBD_DIS	equ 0xAD ; Disable Keyboard
PS2_COMMAND_KBD_EN	equ 0xAE ; Enable Keyboard
PS2_COMMAND_AUX_WRITE	equ 0xD4 ; Write to Auxiliary Device
PS2_COMMAND_RESET_CPU	equ 0xFE ; Reset the CPU

; PS/2 Keyboard Commands
PS2_COMMAND_SET_LEDS	equ 0xED
PS2_COMMAND_SCANSET	equ 0xF0
PS2_COMMAND_RATE	equ 0xF3
PS2_COMMAND_ENABLE	equ 0xF4


; =============================================================================
; EOF
