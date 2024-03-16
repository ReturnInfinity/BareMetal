; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; Driver Includes
; =============================================================================


; Internal
%include "drivers/apic.asm"
%include "drivers/ioapic.asm"
%include "drivers/pcie.asm"
%include "drivers/pci.asm"
%include "drivers/serial.asm"

; Storage
%include "drivers/storage/nvme.asm"
%include "drivers/storage/ahci.asm"
%include "drivers/storage/ata.asm"

; Network
%include "drivers/net/i8254x.asm"
%include "drivers/net/virtio.asm"

; Video
%include "drivers/video/bga.asm"

NIC_DeviceVendor_ID:	; The supported list of NICs

; Virtio
dw 0x1AF4		; Driver ID
dw 0x1AF4		; Vendor ID
dw 0x1000		; Device
dw 0x0000

; Intel 8254x/8257x Gigabit Ethernet
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
dw 0x100E		; 82540EM
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
dw 0x101a		; 82547EI (Mobile)
dw 0x101d		; 82546EB
dw 0x101e		; 82540EP (Mobile)
dw 0x1026		; 82545GM
dw 0x1027		; 82545GM
dw 0x1028		; 82545GM
dw 0x105b		; 82546GB (Copper)
dw 0x105e		; 82571EB/82571GB
dw 0x105f		; 82571EB
dw 0x1060		; 82571EB
dw 0x1075		; 82547GI
dw 0x1076		; 82541GI
dw 0x1077		; 82541GI
dw 0x1078		; 82541ER
dw 0x1079		; 82546GB
dw 0x107a		; 82546GB
dw 0x107b		; 82546GB
dw 0x107c		; 82541PI
dw 0x107d		; 82572EI (Copper)
dw 0x107e		; 82572EI (Fiber)
dw 0x107f		; 82572EI
dw 0x108b		; 82573V (Copper)
dw 0x108c		; 82573E (Copper)
dw 0x109a		; 82573L
dw 0x10a4		; 82571EB
dw 0x10a5		; 82571EB (Fiber)
dw 0x10b5		; 82546GB (Copper)
dw 0x10b9		; 82572EI (Copper)
dw 0x10bc		; 82571EB/82571GB (Copper)
dw 0x10c9		; 82576
dw 0x10d3		; 82574L
dw 0x10d6		; 82575GB
dw 0x10e2		; 82575GB
dw 0x10e6		; 82576
dw 0x10e7		; 82576
dw 0x10e8		; 82576
dw 0x10ea		; 82577LM
dw 0x10eb		; 82577LC
dw 0x10ef		; 82578DM
dw 0x10f0		; 82578DC
dw 0x10f6		; 82574L
dw 0x1107		; 82544EI
dw 0x1112		; 82544GC
dw 0x0000

; End of list
dw 0x0000
dw 0x0000


; =============================================================================
; EOF
