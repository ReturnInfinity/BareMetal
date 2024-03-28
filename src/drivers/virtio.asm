; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; Virtio Definitions and Virtqueue functions
; =============================================================================


; -----------------------------------------------------------------------------
; stub -- description
;  IN:	Nothing
; OUT:	Nothing
;	All other registers preserved
;stub:
;	ret
; -----------------------------------------------------------------------------


; VIRTIO Common Registers
VIRTIO_DEVICEFEATURES			equ 0x00 ; 32-bit Read-only
VIRTIO_HOSTFEATURES			equ 0x04 ; 32-bit
VIRTIO_QUEUEADDRESS			equ 0x08 ; 32-bit
VIRTIO_QUEUESIZE			equ 0x0C ; 16-bit Read-only
VIRTIO_QUEUESELECT			equ 0x0E ; 16-bit
VIRTIO_QUEUENOTIFY			equ 0x10 ; 16-bit
VIRTIO_DEVICESTATUS			equ 0x12 ; 8-bit
VIRTIO_ISRSTATUS			equ 0x13 ; 8-bit Read-only

; VIRTIO_STATUS Values
VIRTIO_STATUS_FAILED			equ 0x80 ; Indicates that something went wrong in the guest, and it has given up on the device
VIRTIO_STATUS_DEVICE_NEEDS_RESET	equ 0x40 ; Indicates that the device has experienced an error from which it can’t recover
VIRTIO_STATUS_FEATURES_OK		equ 0x08 ; Indicates that the driver has acknowledged all the features it understands, and feature negotiation is complete
VIRTIO_STATUS_DRIVER_OK			equ 0x04 ; Indicates that the driver is set up and ready to drive the device
VIRTIO_STATUS_DRIVER			equ 0x02 ; Indicates that the guest OS knows how to drive the device
VIRTIO_STATUS_ACKNOWLEDGE		equ 0x01 ; Indicates that the guest OS has found the device and recognized it as a valid virtio device.

; VIRTQUEUE Flags
VIRTQ_DESC_F_NEXT			equ 1
VIRTQ_DESC_F_WRITE			equ 2
VIRTQ_DESC_F_INDIRECT			equ 4


; =============================================================================
; EOF
