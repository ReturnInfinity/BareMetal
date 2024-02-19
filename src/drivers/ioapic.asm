; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2023 Return Infinity -- see LICENSE.TXT
;
; I/O APIC Functions
; =============================================================================


; -----------------------------------------------------------------------------
; os_ioapic_read -- Read from a register in the I/O APIC
;  IN:	ECX = Register to read
; OUT:	EAX = Register value
;	All other registers preserved
os_ioapic_read:
	push rdx
	mov rdx, [os_IOAPICAddress]
	mov [rdx], ecx			; Write the register #
	mov eax, [rdx+0x10]		; Read the value
	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_ioapic_write -- Write to a register in the I/O APIC
;  IN:	ECX = Register to write
;	EAX = Value to write
; OUT:	All registers preserved
os_ioapic_write:
	push rdx
	mov rdx, [os_IOAPICAddress]
	mov [rdx], ecx			; Write the register #
	mov [rdx+0x10], eax		; Write the value
	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_ioapic_mask_clear -- Clear a mask on the I/O APIC
;  IN:	ECX  = IRQ #
;	EAX  = Interrupt #
; OUT:	All registers preserved
os_ioapic_mask_clear:
	push rcx
	push rax
	shl ecx, 1
	add ecx, 0x10			; Value is 0x10 + (IRQ * 2)
	call os_ioapic_write		; Write the low 32 bits
	add ecx, 1			; Increment for next register
	xor eax, eax
	call os_ioapic_write		; Write the high 32 bits
	pop rax
	pop rcx
	ret
; -----------------------------------------------------------------------------


; Register list
IOAPICID	equ 0x00		; Bits 27:24 - APIC ID
IOAPICVER	equ 0x01		; Bits 23:16 - Max Redirection Entry, 7:0 - I/O APIC Version
IOAPICARB	equ 0x02		; Bits 27:24 - APIC Arbitration ID
IOAPICREDTBL	equ 0x10		; Starting Register for IRQs (0x10-11 for IRQ 0, 0x12-13 for IRQ 1, etc)

; IOAPICREDTBL Info
; Field			Bits	Description
; Vector		7:0	The Interrupt vector that will be raised on the specified CPU(s).
; Delivery Mode		10:8	How the interrupt will be sent to the CPU(s). It can be 000 (Fixed), 001 (Lowest Priority), 010 (SMI), 100 (NMI), 101 (INIT) and 111 (ExtINT).
; Destination Mode	11	Specify how the Destination field shall be interpreted. 0: Physical Destination, 1: Logical Destination
; Delivery Status	12	If 0, the IRQ is just relaxed and waiting for something to happen (or it has fired and already processed by Local APIC(s)). If 1, it means that the IRQ has been sent to the Local APICs but it's still waiting to be delivered.
; Pin Polarity		13	0: Active high, 1: Active low. For ISA IRQs assume Active High unless otherwise specified in Interrupt Source Override descriptors of the MADT or in the MP Tables.
; Remote IRR		14	TODO
; Trigger Mode		15	0: Edge, 1: Level. For ISA IRQs assume Edge unless otherwise specified in Interrupt Source Override descriptors of the MADT or in the MP Tables.
; Mask			16	Just like in the old PIC, you can temporary disable this IRQ by setting this bit, and reenable it by clearing the bit.
; Destination		63:56	This field is interpreted according to the Destination Format bit. If Physical destination is chosen, then this field is limited to bits 56 - 59 (only 16 CPUs addressable). Use the APIC ID of the CPU that you want to receive the interrupt. TODO: Logical destination format...


; =============================================================================
; EOF
