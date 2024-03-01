; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; Serial Functions
; =============================================================================


; -----------------------------------------------------------------------------
serial_init:
	; Disable Interrupts
	mov dx, COM_PORT_INTERRUPT_ENABLE
	mov al, 0			; Disable all interrupts
	out dx, al

	; Enable divisor register for setting baud rate
	mov dx, COM_PORT_LINE_CONTROL
	mov dl, 0x80			; DLB (7 set)
	out dx, al

	; Send the divisor (baud rate will be 115200 / divisor)
	mov dx, COM_PORT_DATA
	mov ax, BAUD_115200
	out dx, al
	mov dx, COM_PORT_DATA+1
	shr ax, 8
	out dx, al

	; Disable divisor register and set values
	mov dx, COM_PORT_LINE_CONTROL
	mov al, 00000111b		; 8 data bits (0-1 set), one stop bit (2 set), no parity (3-5 clear), DLB (7 clear)
	out dx, al

	; Disable modem control
	mov dx, COM_PORT_MODEM_CONTROL
	mov al, 0
	out dx, al

	; Set FIFO
	mov dx, COM_PORT_FIFO_CONTROL
	mov al, 0xC7			; Enable FIFO, clear them, 14-byte threshold
	out dx, al

	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; serial_send -- Send a character via the configured serial port
;  IN:	AL = Character to send
; OUT:	All registers preserved
serial_send:
	push rdx
	push rax

serial_send_wait:
	mov dx, COM_PORT_LINE_STATUS
	in al, dx
	and al, 0x20			; Bit 5
	cmp al, 0
	je serial_send_wait

	; Restore the byte and write to the serial port
	pop rax
	mov dx, COM_PORT_DATA
	out dx, al

	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; serial_recv -- Receives a character via the configured serial port
;  IN:	Nothing
; OUT:	AL = Character received
serial_recv:
	push rdx

	; Check if serial port has pending data
	mov dx, COM_PORT_LINE_STATUS
	in al, dx
	and al, 0x01			; Bit 0
	cmp al, 0
	je serial_recv_nochar

	; Read from the serial port
	mov dx, COM_PORT_DATA
	in al, dx
	cmp al, 0x0D			; Enter via serial?
	je serial_recv_enter
	cmp al, 0x7F			; Backspace via serial?
	je serial_recv_backspace

	; Store the receive character to the key var
serial_recv_store:
	mov [key], al

serial_recv_nochar:
	pop rdx
	ret

serial_recv_enter:
	mov al, 0x1C			; Adjust it to the same value as a keyboard
	jmp serial_recv_store
serial_recv_backspace:
	mov al, 0x0E			; Adjust it to the same value as a keyboard
	jmp serial_recv_store
; -----------------------------------------------------------------------------


; Port Registers
COM_BASE			equ 0x3F8
COM_PORT_DATA			equ COM_BASE + 0
COM_PORT_INTERRUPT_ENABLE	equ COM_BASE + 1
COM_PORT_FIFO_CONTROL		equ COM_BASE + 2
COM_PORT_LINE_CONTROL		equ COM_BASE + 3
COM_PORT_MODEM_CONTROL		equ COM_BASE + 4
COM_PORT_LINE_STATUS		equ COM_BASE + 5
COM_PORT_MODEM_STATUS		equ COM_BASE + 6
COM_PORT_SCRATCH_REGISTER	equ COM_BASE + 7

; Baud Rates
BAUD_115200			equ 1
BAUD_57600			equ 2
BAUD_9600			equ 12
BAUD_300			equ 384


; =============================================================================
; EOF