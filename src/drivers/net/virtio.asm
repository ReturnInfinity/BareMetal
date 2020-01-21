; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2020 Return Infinity -- see LICENSE.TXT
;
; Virtio NIC Driver
; =============================================================================


; -----------------------------------------------------------------------------
; Initialize a Virtio NIC
;  IN:	EDX = Packed PCI address (as per pci.asm)
net_virtio_init:
	push rsi
	push rdx
	push rcx
	push rax

	; Grab the Base I/O Address of the device
	mov dl, 0x04			; BAR0
	call os_pci_read
	; Todo: Make sure bit 0 is 1
	and eax, 0xFFFFFFFC		; Clear the low two bits
	mov dword [os_NetIOBaseMem], eax

	; Grab the IRQ of the device
	mov dl, 0x0F			; Get device's IRQ number from PCI Register 15 (IRQ is bits 7-0)
	call os_pci_read
	mov [os_NetIRQ], al		; AL holds the IRQ

	; Grab the MAC address
	mov edx, [os_NetIOBaseMem]
	add edx, 0x14
	in al, dx
	mov [os_NetMAC], al
	inc dx
	in al, dx
	mov [os_NetMAC+1], al
	inc dx
	in al, dx
	mov [os_NetMAC+2], al
	inc dx
	in al, dx
	mov [os_NetMAC+3], al
	inc dx
	in al, dx
	mov [os_NetMAC+4], al
	inc dx
	in al, dx
	mov [os_NetMAC+5], al

;	jmp $

	; Reset the device
	call net_virtio_reset

	pop rax
	pop rcx
	pop rdx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_virtio_reset - Reset a Virtio NIC
;  IN:	Nothing
; OUT:	Nothing, all registers preserved
net_virtio_reset:


; Acknowledge

; Driver

; Queue

	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_virtio_transmit - Transmit a packet via a Virtio NIC
;  IN:	RSI = Location of packet
;	RCX = Length of packet
; OUT:	Nothing
net_virtio_transmit:

	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_virtio_poll - Polls the Virtio NIC for a received packet
;  IN:	RDI = Location to store packet
; OUT:	RCX = Length of packet
net_virtio_poll:

	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; net_virtio_ack_int - Acknowledge an internal interrupt of the Virtio NIC
;  IN:	Nothing
; OUT:	RAX = Ethernet status
;	Uses RDI
net_virtio_ack_int:

	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
