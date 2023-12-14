; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2023 Return Infinity -- see LICENSE.TXT
;
; BGA Driver
; =============================================================================


; -----------------------------------------------------------------------------
init_bga:
	; Get the base address of the frame buffer
	mov dl, 4			; Register 4 for BAR0
	xor eax, eax
	call os_pci_read
	and eax, 0xFFFFFFF0		; Clear the lowest 4 bits
	mov rbx, rax			; Copy frame buffer address

	; Get BGA version
	mov ax, VBE_DISPI_INDEX_ID
	mov dx, VBE_DISPI_IOPORT_INDEX
	out dx, ax
	mov dx, VBE_DISPI_IOPORT_DATA
	in ax, dx
	; TODO - Check that AX is >= 0xB0C0 and <= 0xB0C5

	; Disable video
	mov ax, VBE_DISPI_INDEX_ENABLE
	mov dx, VBE_DISPI_IOPORT_INDEX
	out dx, ax
	mov ax, VBE_DISPI_DISABLED
	mov dx, VBE_DISPI_IOPORT_DATA
	out dx, ax

	; Set X	
	mov ax, VBE_DISPI_INDEX_XRES
	mov dx, VBE_DISPI_IOPORT_INDEX
	out dx, ax
	mov ax, screen_x
	mov dx, VBE_DISPI_IOPORT_DATA
	out dx, ax

	; Set Y
	mov ax, VBE_DISPI_INDEX_YRES
	mov dx, VBE_DISPI_IOPORT_INDEX
	out dx, ax
	mov ax, screen_y
	mov dx, VBE_DISPI_IOPORT_DATA
	out dx, ax

	; Set BPP
	mov ax, VBE_DISPI_INDEX_BPP
	mov dx, VBE_DISPI_IOPORT_INDEX
	out dx, ax
	mov ax, screen_bpp
	mov dx, VBE_DISPI_IOPORT_DATA
	out dx, ax

	; Enable video
	mov ax, VBE_DISPI_INDEX_ENABLE
	mov dx, VBE_DISPI_IOPORT_INDEX
	out dx, ax
	mov ax, VBE_DISPI_ENABLED | VBE_DISPI_LFB_ENABLED
	mov dx, VBE_DISPI_IOPORT_DATA
	out dx, ax

	; Verify
	mov ax, VBE_DISPI_INDEX_ENABLE
	mov dx, VBE_DISPI_IOPORT_INDEX
	out dx, ax
	mov dx, VBE_DISPI_IOPORT_DATA
	in ax, dx
	cmp ax, VBE_DISPI_ENABLED | VBE_DISPI_LFB_ENABLED
	jne init_video_fail

	; Get LFB length (supported in BGA version 0xB0C5)
	mov ax, VBE_DISPI_INDEX_VIDEO_MEMORY_64K
	mov dx, VBE_DISPI_IOPORT_INDEX
	out dx, ax
	mov dx, VBE_DISPI_IOPORT_DATA
	in ax, dx
	shl rax, 16			; LFB length in bytes
	; TODO - Save the LFB length value

	; Set kernel values
	mov qword [os_screen_lfb], rbx
	mov word [os_screen_x], screen_x
	mov word [os_screen_y], screen_y
	mov byte [os_screen_bpp], screen_bpp

	ret
; -----------------------------------------------------------------------------


; BGA Ports
VBE_DISPI_IOPORT_INDEX			equ 0x01CE
VBE_DISPI_IOPORT_DATA			equ 0x01CF

; BGA Registers
VBE_DISPI_INDEX_ID			equ 0x00	; Return version
VBE_DISPI_INDEX_XRES			equ 0x01	; Set/Return X resolution
VBE_DISPI_INDEX_YRES			equ 0x02	; Set/Return Y resolution
VBE_DISPI_INDEX_BPP			equ 0x03	; Set/Return bit depth
VBE_DISPI_INDEX_ENABLE			equ 0x04
VBE_DISPI_INDEX_BANK			equ 0x05
VBE_DISPI_INDEX_VIRT_WIDTH		equ 0x06
VBE_DISPI_INDEX_VIRT_HEIGHT		equ 0x07
VBE_DISPI_INDEX_X_OFFSET		equ 0x08
VBE_DISPI_INDEX_Y_OFFSET		equ 0x09
VBE_DISPI_INDEX_VIDEO_MEMORY_64K	equ 0x0A	; Returns LFB size in 64KiB blocks

; BGA Values
VBE_DISPI_DISABLED			equ 0x00
VBE_DISPI_ENABLED			equ 0x01
VBE_DISPI_GETCAPS			equ 0x02	; For returning max when reading XRES, YRES, and BPP
VBE_DISPI_8BIT_DAC			equ 0x20
VBE_DISPI_LFB_ENABLED			equ 0x40
VBE_DISPI_NOCLEARMEM			equ 0x80


; =============================================================================
; EOF
