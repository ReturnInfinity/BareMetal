; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Driver Includes
; =============================================================================


; Internal
%include "drivers/apic.asm"
%include "drivers/hpet.asm"
%include "drivers/ioapic.asm"
%include "drivers/pcie.asm"
%include "drivers/pci.asm"
%include "drivers/ps2.asm"
%include "drivers/serial.asm"
%include "drivers/virtio.asm"

; Storage
%include "drivers/storage/nvme.asm"
%include "drivers/storage/ahci.asm"
%include "drivers/storage/virtio-blk.asm"
%include "drivers/storage/ata.asm"

; Network
%include "drivers/net/i8254x.asm"
%include "drivers/net/i8257x.asm"
%include "drivers/net/i8259x.asm"
%include "drivers/net/r8169.asm"
%include "drivers/net/virtio-net.asm"

NIC_DeviceVendor_ID:	; The supported list of NICs

; Virtio
dw 0x1AF4		; Driver ID
dw 0x1AF4		; Vendor ID
dw 0x1000		; Device ID - legacy
dw 0x1041		; Device ID - v1.0
dw 0x0000

; Intel 8254x Gigabit Ethernet
dw 0x8254		; Driver ID
dw 0x8086		; Vendor ID
dw 0x1000		; 82542 (Fiber)
dw 0x1001		; 82543GC (Fiber)
dw 0x1004		; 82543GC (Copper)
dw 0x1008		; 82544EI (Copper)
dw 0x1009		; 82544EI (Fiber)
dw 0x100A		; 82540EM
dw 0x100C		; 82544GC (Copper)
dw 0x100D		; 82544GC (LOM)
dw 0x100E		; 82540EM - QEMU e1000
dw 0x100F		; 82545EM (Copper)
dw 0x1010		; 82546EB (Copper)
dw 0x1011		; 82545EM (Fiber)
dw 0x1012		; 82546EB (Fiber)
dw 0x1013		; 82541EI
dw 0x1014		; 82541ER
dw 0x1015		; 82540EM (LOM)
dw 0x1016		; 82540EP (Mobile)
dw 0x1017		; 82540EP
dw 0x1018		; 82541EI
dw 0x1019		; 82547EI
dw 0x101A		; 82547EI (Mobile)
dw 0x101D		; 82546EB
dw 0x101E		; 82540EP (Mobile)
dw 0x1026		; 82545GM
dw 0x1027		; 82545GM
dw 0x1028		; 82545GM
dw 0x1075		; 82547GI
dw 0x1076		; 82541GI
dw 0x1077		; 82541GI
dw 0x1078		; 82541ER
dw 0x1079		; 82546GB
dw 0x107A		; 82546GB
dw 0x107B		; 82546GB
dw 0x107C		; 82541PI
dw 0x108A		; 82546GB
dw 0x1099		; 82546GB (Copper)
dw 0x10B5		; 82546GB (Copper)
dw 0x0000

; Intel 8257x Gigabit Ethernet
dw 0x8257		; Driver ID
dw 0x8086		; Vendor ID
dw 0x105E		; 82571EB/82571GB
dw 0x105F		; 82571EB
dw 0x1060		; 82571EB
dw 0x1075		; 82547GI
dw 0x107D		; 82572EI (Copper)
dw 0x107E		; 82572EI (Fiber)
dw 0x107F		; 82572EI
dw 0x108B		; 82573V (Copper)
dw 0x108C		; 82573E (Copper)
dw 0x109A		; 82573L
dw 0x10A4		; 82571EB
dw 0x10A5		; 82571EB (Fiber)
dw 0x10B9		; 82572EI (Copper)
dw 0x10BC		; 82571EB/82571GB (Copper)
dw 0x10C9		; 82576
dw 0x10D3		; 82574L - QEMU e1000e
dw 0x10D6		; 82575GB
dw 0x10E2		; 82575GB
dw 0x10E6		; 82576
dw 0x10E7		; 82576
dw 0x10E8		; 82576
dw 0x10EA		; 82577LM
dw 0x10EB		; 82577LC
dw 0x10EF		; 82578DM
dw 0x10F0		; 82578DC
dw 0x10F6		; 82574L
dw 0x153A		; I217-LM
dw 0x153B		; I217-V
dw 0x0000

; Intel 8259x/X540/X550 10 Gigabit Ethernet
dw 0x8259		; Driver ID
dw 0x8086		; Vendor ID
dw 0x1560		; X540T1
dw 0x0000

; Realtek 816x/811x Gigabit Ethernet
dw 0x8169		; Driver ID
dw 0x10EC		; Vendor ID
dw 0x8161		; 8111/8168/8411 PCI Express
dw 0x8167		; 8110SC/8169SC
dw 0x8168		; 8111/8168/8211/8411 PCI Express
dw 0x8169		; 8169
dw 0x0000

; End of list
dw 0x0000
dw 0x0000


; =============================================================================
; EOF
