; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2023 Return Infinity -- see LICENSE.TXT
;
; Initialize video
; =============================================================================


; -----------------------------------------------------------------------------
init_video:
	; Check PCI Table for a supported controller
	mov rsi, pci_table		; Load PCI Table address to RSI
	sub rsi, 16
	add rsi, 8			; Add offset to Class Code
init_video_check_pci:
	add rsi, 16			; Increment to next record in memory
	mov ax, [rsi]			; Load Class Code / Subclass Code
	cmp ax, 0xFFFF			; Check if at end of list
	je init_video_done
	cmp ax, 0x0300			; Display controller (03) / VGA compatible controller (00)
	je init_video_check_id
	jmp init_video_check_pci	; Check PCI Table again

init_video_check_id:
	sub rsi, 8			; Move RSI back to start of PCI record
	mov edx, [rsi]			; Load value for os_pci_read/write

	mov dl, 0			; Register 0 for Device/Vendor IDs
	xor eax, eax
	call os_pci_read
	cmp eax, 0x11111234		; QEMU/ Bochs
	je init_video_found_bga
	cmp eax, 0xBEEF80EE		; VirtualBox
	je init_video_found_bga
	jmp init_video_done

init_video_found_bga:
	call init_bga

init_video_done:
	ret

init_video_fail:
	mov eax, 0xFFFFFFFF
	jmp $
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
