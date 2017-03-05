; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2017 Return Infinity -- see LICENSE.TXT
;
; Initialize PCI
; =============================================================================


; -----------------------------------------------------------------------------
init_pci:
	mov eax, 0x80000000
	mov ebx, eax
	mov edx, PCI_CONFIG_ADDRESS
	out dx, eax
	in eax, dx
	cmp eax, ebx
	sete al
	mov byte [os_PCIEnabled], al
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF