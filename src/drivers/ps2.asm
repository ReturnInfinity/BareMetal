; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
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

	; Enable mouse
;	mov al, PS2_COMMAND_AUX_EN
;	call ps2_send_cmd

	; Init keyboard
	; TODO - set rate

	; Init mouse
	call ps2_mouse_init

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


;-----------------------------------------------------------------------------
ps2_mouse_interrupt:
	push rcx
	push rbx
	push rax

	mov ecx, 1000
	xor eax, eax
mouse_wait:
	in al, PS2_STATUS
	dec cl
	jnz mouse_getbyte
	pop rax
	pop rbx
	pop rcx
	iretq

mouse_getbyte:
	and al, 0x20			; Check bit 5 (set if data is from mouse)
	jz mouse_wait			; If not, wait for more data
	in al, PS2_DATA			; Get a byte of data from the mouse
	mov cl, al			; Save the byte to CL
;	in al, 0x61			; Read byte from keyboard controller unused port
;	out 0x61, al			; Write same byte back to keyboard controller unused port
	xor ebx, ebx
	mov bl, [os_ps2_mouse_count]	; Get the byte counter
	add ebx, os_ps2_mouse_packet	; Add the address of the mouse packet
	mov [ebx], cl			; Store the byte in CL to the correct index into the mouse packet
	inc byte [os_ps2_mouse_count]	; Increment the byte counter
	mov bl, [os_ps2_mouse_count]	; Copy the byte counter value to BL 
	cmp bl, [packetsize]		; Compare byte counter to excepted packet size
	jb mouse_end			; If below then bail out, wait for rest of packet
	mov word [os_ps2_mouse_count], 0	; At this point we have a full packet. Clear the byte counter

	; Process the mouse packet

	; Get state of buttons as well as X/Y sign
	xor eax, eax
	mov al, [os_ps2_mouse_packet]	; State of the buttons
	; TODO - Check X/Y overflow. If either are set then no movement, bail out
	and al, 7			; Keep the low 3 bits for the buttons
	mov [os_ps2_mouse_buttons], ax

	; Process byte for Delta X - Left is negative (128-255), Right is positive (1-127)
	mov bl, [os_ps2_mouse_packet+1]	; Load Delta X from mouse packet
	cmp bl, 0			; Check if it was 0
	je mouse_skip_x_movement
	movsx eax, bl			; Sign extend the Delta for X movement
	add [os_ps2_mouse_x], ax
mouse_skip_x_movement:

	; Process byte for Delta Y - Up is positive (1-127), Down is negative (128-255)
	mov bl, [os_ps2_mouse_packet+2]	; Load Delta Y from mouse packet
	cmp bl, 0			; Check if it was 0
	je mouse_skip_y_movement	; If so, jump past setting cursor Y location
	not bl				; Flip value since Y direction is, in my opinion, backwards - 0xFF becomes 0x00
	inc bl				; Add 1
	movsx eax, bl			; Sign extend the Delta for Y movement
	add [os_ps2_mouse_y], ax
mouse_skip_y_movement:

	; Keep cursor on the screen
	; X
	mov bx, [os_screen_x]		; Screen X dimension in number of pixels
	dec bx				; Decrement by one since valid pixels are 0 thru X-1
	mov ax, [os_ps2_mouse_x]	; Get the current X value for the mouse location
	cmp ax, 0xF000			; Check if it wrapped around below 0
	ja checkx_min			; If so jump to min
	cmp ax, bx			; Check X value against valid max pixel location
	jle checkx_end			; If less or equal then mouse cursor is on screen
checkx_max:				; If greater then mouse cursor has moved off the right edge
	mov [os_ps2_mouse_x], bx	; Set the mouse X location to Screen X-1
	jmp checkx_end
checkx_min:
	xor ax, ax			; Clear AX
	mov [os_ps2_mouse_x], ax	; Set the mouse X location to 0
checkx_end:
	; Y
	mov bx, [os_screen_y]		; Screen Y dimension in number of pixels
	dec bx				; Decrement by one since valid pixels are 0 thru Y-1
	mov ax, [os_ps2_mouse_y]	; Get the current Y value for the mouse location
	cmp ax, 0xF000			; Check if it wrapped around below 0
	ja checky_min			; If so jump to min
	cmp ax, bx			; Check Y value against valid max pixel location
	jle checky_end			; If less or equal then mouse cursor is on screen
checky_max:				; If greater then mouse cursor has moved off the bottom edge
	mov [os_ps2_mouse_y], bx	; Set the mouse Y location to Screen Y-1
	jmp checky_end
checky_min:
	xor ax, ax			; Clear AX
	mov [os_ps2_mouse_y], ax	; Set the mouse Y location to 0
checky_end:

mouse_end:
	pop rax
	pop rbx
	pop rcx
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
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; ps2_mouse_write/ps2_mouse_read
;  IN:	AL = byte to send (ps2_mouse_write only)
; OUT:	AL = byte received
ps2_mouse_write:
	mov dh, al
	mov dl, 2
	call ps2wait
	mov al, PS2_AUX_WRITE
	out PS2_CMD, al
	call ps2wait
	mov al, dh
	out PS2_DATA, al
	; no ret, fall into read code to read acknowledgement
ps2_mouse_read:
	mov dl, 1
	call ps2wait
	in al, PS2_DATA
	ret
; -----------------------------------------------------------------------------

; Variables
packetsize: db 0
resolution: db 3 ; 8 count/mm
samplerate: db 200 ; Decimal value - Samples/second

ps2_mouse_init:
	xor eax, eax
	mov dl, 2			; Wait for write to be empty
	call ps2wait
	mov al, PS2_AUX_EN		; Enable mouse. Bit 5 of CCB should be clear
	out PS2_CMD, al			; Send command to PS2 controller
	call ps2_mouse_read		; Read acknowledgement
	mov dl, 2			; Wait for write to be empty
	call ps2wait

	mov al, PS2_RD_CCB		; Command to Read "byte 0" from internal RAM
	out PS2_CMD, al			; Send command to PS2 controller
	mov dl, 1			; Wait for read to be empty
	call ps2wait
	in al, PS2_DATA			; Read data byte from PS2 controller
	bt ax, 5			; Check if bit 5 is clear
	jc ps2_mouse_init_fail		; If not, jump to end - no AUX

	bts ax, 1			; Set bit 1 to enable second PS/2 port interrupts
	btr ax, 5			; Clear bit 5 to enable second PS/2 port clock
	mov bl, al			; Save new CCB value to BL
	mov dl, 2

	call ps2wait
	mov al, PS2_WR_CCB		; Write next byte to "byte 0" of internal RAM
	out PS2_CMD, al
	call ps2wait
	mov al, bl			; Restore new CCB value from BL
	out PS2_DATA, al
	mov dl, 1
	call ps2wait			; Get optional acknowledgement

	; Set mouse parameters
	mov byte [packetsize], 3
	mov al, PS2_SETDEFAULTS
	call ps2_mouse_write
	mov al, PS2_SETSAMPLERATE
	call ps2_mouse_write
	mov al, byte [samplerate]
	call ps2_mouse_write
	mov al, PS2_SETRESOLUTION
	call ps2_mouse_write
	mov al, byte [resolution]
	call ps2_mouse_write
	mov al, PS2_SETSCALING1TO1
	call ps2_mouse_write
	mov al, PS2_ENABLEPACKETSTREAM
	call ps2_mouse_write

	; Reset mouse variables
	xor eax, eax
	mov [os_ps2_mouse_count], ax
	mov [os_ps2_mouse_buttons], ax
	mov [os_ps2_mouse_x], ax
	mov [os_ps2_mouse_y], ax

	; Set flag that the PS/2 mouse was enabled
	or qword [os_SysConfEn], 1 << 1

ps2_mouse_init_fail:
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
PS2_AUX_WRITE		equ 0xD4 ; Write to Auxiliary Device
PS2_RESET_CPU		equ 0xFE ; Reset the CPU

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
