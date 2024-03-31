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

; VIRTIO MMIO Common Registers
VIRTIO_DEVICE_FEATURE_SELECT		equ 0x00 ; 32-bit
VIRTIO_DEVICE_FEATURE			equ 0x04 ; 32-bit Read-only
VIRTIO_DRIVER_FEATURE_SELECT		equ 0x08 ; 32-bit
VIRTIO_DRIVER_FEATURE			equ 0x0C ; 32-bit
VIRTIO_CONFIG_MSIX_VECTOR		equ 0x10 ; 16-bit
VIRTIO_NUM_QUEUES			equ 0x12 ; 16-bit Read-only
VIRTIO_DEVICE_STATUS			equ 0x14 ; 8-bit
VIRTIO_CONFIG_GENERATION		equ 0x15 ; 8-bit Read-only
VIRTIO_QUEUE_SELECT			equ 0x16 ; 16-bit
VIRTIO_QUEUE_SIZE			equ 0x18 ; 16-bit
VIRTIO_QUEUE_MSIX_VECTOR		equ 0x1A ; 16-bit
VIRTIO_QUEUE_ENABLE			equ 0x1C ; 16-bit
VIRTIO_QUEUE_NOTIFY_OFF			equ 0x1E ; 16-bit Read-only
VIRTIO_QUEUE_DESC			equ 0x20 ; 64-bit
VIRTIO_QUEUE_DRIVER			equ 0x28 ; 64-bit
VIRTIO_QUEUE_DEVICE			equ 0x30 ; 64-bit
VIRTIO_QUEUE_NOTIFY_DATA		equ 0x38 ; 16-bit Read-only
VIRTIO_QUEUE_RESET			equ 0x3A ; 16-bit

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

; VIRTIO Feature Bits
VIRTIO_F_INDIRECT_DESC			equ 28
VIRTIO_F_EVENT_IDX			equ 29
VIRTIO_F_VERSION_1			equ 32
VIRTIO_F_ACCESS_PLATFORM		equ 33
VIRTIO_F_RING_PACKED			equ 34
VIRTIO_F_IN_ORDER			equ 35
VIRTIO_F_ORDER_PLATFORM			equ 36
VIRTIO_F_SR_IOV				equ 37
VIRTIO_F_NOTIFICATION_DATA		equ 38
VIRTIO_F_NOTIF_CONFIG_DATA		equ 39
VIRTIO_F_RING_RESET			equ 40

; =============================================================================
; EOF
