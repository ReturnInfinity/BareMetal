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
	; TODO - Check that AX is >= 0xB0C0 and <= 0xB0C6

	; Disable video
	mov ax, VBE_DISPI_INDEX_ENABLE
	mov dx, VBE_DISPI_IOPORT_INDEX
	out dx, ax
	mov ax, 0x00
	mov dx, VBE_DISPI_IOPORT_DATA
	out dx, ax

	; Set X	
	mov ax, VBE_DISPI_INDEX_XRES
	mov dx, VBE_DISPI_IOPORT_INDEX
	out dx, ax
	mov ax, 800
	mov dx, VBE_DISPI_IOPORT_DATA
	out dx, ax

	; Set Y
	mov ax, VBE_DISPI_INDEX_YRES
	mov dx, VBE_DISPI_IOPORT_INDEX
	out dx, ax
	mov ax, 600
	mov dx, VBE_DISPI_IOPORT_DATA
	out dx, ax

	; Set BPP
	mov ax, VBE_DISPI_INDEX_BPP
	mov dx, VBE_DISPI_IOPORT_INDEX
	out dx, ax
	mov ax, 32
	mov dx, VBE_DISPI_IOPORT_DATA
	out dx, ax

	; Enable video
	mov ax, VBE_DISPI_INDEX_ENABLE
	mov dx, VBE_DISPI_IOPORT_INDEX
	out dx, ax
	mov ax, 0x41			; Bit 6 (LFB), Bit 0 (Enabled)
	mov dx, VBE_DISPI_IOPORT_DATA
	out dx, ax

	; Verify
	mov ax, VBE_DISPI_INDEX_ENABLE
	mov dx, VBE_DISPI_IOPORT_INDEX
	out dx, ax
	mov dx, VBE_DISPI_IOPORT_DATA
	in ax, dx
	cmp ax, 0x41			; Bit 6 (LFB), Bit 0 (Enabled)
	jne init_video_fail

	; Overwrite values from Pure64
	mov rdi, 0x5080
	mov eax, ebx			; Frame Buffer Address
	stosd
	mov eax, 800
	stosw
	mov eax, 600
	stosw
	mov eax, 32
	stosw

	ret
; -----------------------------------------------------------------------------


; Register list
VBE_DISPI_IOPORT_INDEX		equ 0x01CE
VBE_DISPI_IOPORT_DATA		equ 0x01CF

VBE_DISPI_INDEX_ID		equ 0x00	; 
VBE_DISPI_INDEX_XRES		equ 0x01	; 
VBE_DISPI_INDEX_YRES		equ 0x02	; 
VBE_DISPI_INDEX_BPP		equ 0x03	; 
VBE_DISPI_INDEX_ENABLE		equ 0x04	; 
VBE_DISPI_INDEX_BANK		equ 0x05	; 
VBE_DISPI_INDEX_VIRT_WIDTH	equ 0x06	; 
VBE_DISPI_INDEX_VIRT_HEIGHT	equ 0x07	; 
VBE_DISPI_INDEX_X_OFFSET	equ 0x08	; 
VBE_DISPI_INDEX_Y_OFFSET	equ 0x09	; 

VBE_DISPI_DISABLED		equ 0x00
VBE_DISPI_ENABLED		equ 0x01
VBE_DISPI_GETCAPS		equ 0x02
VBE_DISPI_8BIT_DAC		equ 0x20
VBE_DISPI_LFB_ENABLED		equ 0x40
VBE_DISPI_NOCLEARMEM		equ 0x80


; =============================================================================
; EOF
