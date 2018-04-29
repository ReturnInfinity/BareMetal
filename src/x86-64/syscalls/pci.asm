; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2017 Return Infinity -- see LICENSE.TXT
;
; PCI Functions
; =============================================================================


; -----------------------------------------------------------------------------
; b_pci_read_config --Read PCI configuration data.
; IN:	RDI = bus index
;    	RSI = device index
;    	RDX = function index
;    	RCX = offset
; OUT:	RAX a 16-bit word containing the configuration data.
;     	All other registers preserved
b_pci_read_config:

	push rdi	; preserve the bus index
	push rsi	; preserve the device index
	push rdx	; preserve the function index
	push rcx	; preserve the offset
	push r8		; preserve r8, used for the 'enable bit'

	shl rdi, 16	   ; shift the bus index
	shl rsi, 11	   ; shift the device index
	shl rdx, 8	   ; shift the function index
	and rcx, 0xFC	   ; discard lower bits of offset
	mov r8, 0x80000000 ; r8 contains the 'enable bit'

	xor eax, eax	; put the config address into eax
	or eax, edi	; or the bus index
	or eax, esi	; or the device index
	or eax, edx	; or the function index
	or eax, ecx	; or the offset
	or eax, r8d	; or the 'enable bit'

	mov dx, 0x0CF8	; move PCI config address into port register
	out dx, eax	; write PCI config data

	mov dx, 0x0CFC	; move PCI config data address into port register
	in eax, dx	; read PCI data

	and ecx, 0x02	; shift the higher word of eax if needed
	shl ecx, 0x03	; turn ecx into a bit value (multiply by 8)
	shr eax, cl	; shift output data by bit count in ecx
	and eax, 0xFFFF ; make sure only 16 bits of data is contained by eax

	pop r8		; restore r8
	pop rcx		; restore offset
	pop rdx		; restore function index
	pop rsi		; restore device index
	pop rdi		; restore bus index

	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
