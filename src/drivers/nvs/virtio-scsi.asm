; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; Virtio SCSI Driver
; =============================================================================


; -----------------------------------------------------------------------------
nvs_virtio_scsi_init:
	push rsi
	push rdx			; RDX should already point to a supported device for os_bus_read/write
	push rbx
	push rax

	; Gather the Base I/O Address of the device
	mov al, 4			; Read BAR4
	call os_bus_read_bar
	mov [os_virtioscsi_base], rax	; Save it as the base
	mov rsi, rax			; RSI holds the base for MMIO

	; Set PCI Status/Command values
	mov dl, 0x01			; Read Status/Command
	call os_bus_read
	bts eax, 10			; Set Interrupt Disable
	bts eax, 2			; Enable Bus Master
	bts eax, 1			; Enable Memory Space
	call os_bus_write		; Write updated Status/Command

	; Gather required values from PCI Capabilities
	mov dl, 1
	call os_bus_read		; Read register 1 for Status/Command
	bt eax, 20			; Check bit 4 of the Status word (31:16)
	jnc virtio_scsi_init_error	; If if doesn't exist then bail out
	mov dl, 13
	call os_bus_read		; Read register 13 for the Capabilities Pointer (7:0)
	and al, 0xFC			; Clear the bottom two bits as they are reserved

virtio_scsi_init_cap_next:
	shr al, 2			; Quick divide by 4
	mov dl, al
	call os_bus_read
	cmp al, VIRTIO_PCI_CAP_VENDOR_CFG
	je virtio_scsi_init_cap
	shr eax, 8
	jmp virtio_scsi_init_cap_next_offset

virtio_scsi_init_cap:
	rol eax, 8			; Move Virtio cfg_type to AL
	cmp al, VIRTIO_PCI_CAP_COMMON_CFG
	je virtio_scsi_init_cap_common
	cmp al, VIRTIO_PCI_CAP_NOTIFY_CFG
	je virtio_scsi_init_cap_notify
	ror eax, 16			; Move next entry offset to AL
	jmp virtio_scsi_init_cap_next_offset

virtio_scsi_init_cap_common:
	push rdx
	; TODO Check for BAR4 and offset of 0x0
	pop rdx
	jmp virtio_scsi_init_cap_next_offset

virtio_scsi_init_cap_notify:
	push rdx
	inc dl
	call os_bus_read
	pop rdx
	cmp al, 0x04			; Needs to be BAR4
	jne virtio_scsi_init_error
	push rdx
	add dl, 2
	call os_bus_read
	mov [notify_offset], eax
	add dl, 2			; Skip Length
	call os_bus_read
	mov [notify_offset_multiplier], eax
	pop rdx
	jmp virtio_scsi_init_cap_next_offset

virtio_scsi_init_cap_next_offset:
	call os_bus_read
	shr eax, 8			; Shift pointer to AL
	cmp al, 0x00			; End of linked list?
	jne virtio_scsi_init_cap_next	; If not, continue reading

virtio_scsi_init_cap_end:

	; Device Initialization (section 3.1)

	; 3.1.1 - Step 1 -  Reset the device (section 2.4)
	mov al, 0x00
	mov [rsi+VIRTIO_DEVICE_STATUS], al
virtio_scsi_init_reset_wait:
	mov al, [rsi+VIRTIO_DEVICE_STATUS]
	cmp al, 0x00
	jne virtio_scsi_init_reset_wait

	; 3.1.1 - Step 2 - Tell the device we see it
	mov al, VIRTIO_STATUS_ACKNOWLEDGE
	mov [rsi+VIRTIO_DEVICE_STATUS], al

	; 3.1.1 - Step 3 - Tell the device we support it
	mov al, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER
	mov [rsi+VIRTIO_DEVICE_STATUS], al

	; 3.1.1 - Step 4
	; Process the first 32-bits of Feature bits
	xor eax, eax
	mov [rsi+VIRTIO_DEVICE_FEATURE_SELECT], eax
	mov eax, [rsi+VIRTIO_DEVICE_FEATURE]
	mov eax, 0x04			; Only support VIRTIO_SCSI_F_CHANGE (4)
	push rax
	xor eax, eax
	mov [rsi+VIRTIO_DRIVER_FEATURE_SELECT], eax
	pop rax
	mov [rsi+VIRTIO_DRIVER_FEATURE], eax
	; Process the next 32-bits of Feature bits
	mov eax, 1
	mov [rsi+VIRTIO_DEVICE_FEATURE_SELECT], eax
	mov eax, [rsi+VIRTIO_DEVICE_FEATURE]
	and eax, 1
	push rax
	mov eax, 1
	mov [rsi+VIRTIO_DRIVER_FEATURE_SELECT], eax
	pop rax
	mov [rsi+VIRTIO_DRIVER_FEATURE], eax

	; 3.1.1 - Step 5
	mov al, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_FEATURES_OK
	mov [rsi+VIRTIO_DEVICE_STATUS], al

	; 3.1.1 - Step 6 - Re-read device status to make sure FEATURES_OK is still set
	mov al, [rsi+VIRTIO_DEVICE_STATUS]
	bt ax, 3			; VIRTIO_STATUS_FEATURES_OK
	jnc virtio_scsi_init_error

	; 3.1.1 - Step 7
	; Set up the device and the queues
	; discovery of virtqueues for the device
	; optional per-bus setup
	; reading and possibly writing the device’s virtio configuration space
	; population of virtqueues

	; Set up Queue 0 - CONTROLQ
	xor eax, eax
	mov [rsi+VIRTIO_QUEUE_SELECT], ax
	mov ax, [rsi+VIRTIO_QUEUE_SIZE]	; Return the size of the queue
	mov ecx, eax			; Store queue size in ECX
	mov eax, os_nvs_mem
	mov [rsi+VIRTIO_QUEUE_DESC], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DESC+8], eax
	rol rax, 32
	add rax, 4096
	mov [rsi+VIRTIO_QUEUE_DRIVER], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DRIVER+8], eax
	rol rax, 32
	add rax, 4096
	mov [rsi+VIRTIO_QUEUE_DEVICE], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DEVICE+8], eax
	rol rax, 32
	mov ax, 1
	mov [rsi+VIRTIO_QUEUE_ENABLE], ax

	; Populate the Next entries in the description ring
	; FIXME - Don't expect exactly 256 entries
	mov eax, 1
	mov rdi, os_nvs_mem
	add rdi, 14
virtio_scsi_init_pop:
	mov [rdi], al
	add rdi, 16
	add al, 1
	cmp al, 0
	jne virtio_scsi_init_pop

	; Gather Device Configuration Layout
	; Parse how many request queues exist

	; Set up Queue 2 - REQUESTQUEUE
	mov eax, 2
	mov [rsi+VIRTIO_QUEUE_SELECT], ax
	mov ax, [rsi+VIRTIO_QUEUE_SIZE]	; Return the size of the queue
	mov ecx, eax			; Store queue size in ECX
	mov eax, os_nvs_mem
	add eax, 16384			; TODO remove hardcoded values
	mov [rsi+VIRTIO_QUEUE_DESC], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DESC+8], eax
	rol rax, 32
	add rax, 4096
	mov [rsi+VIRTIO_QUEUE_DRIVER], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DRIVER+8], eax
	rol rax, 32
	add rax, 4096
	mov [rsi+VIRTIO_QUEUE_DEVICE], eax
	rol rax, 32
	mov [rsi+VIRTIO_QUEUE_DEVICE+8], eax
	rol rax, 32
	mov ax, 1
	mov [rsi+VIRTIO_QUEUE_ENABLE], ax

	; Populate the Next entries in the description ring
	; FIXME - Don't expect exactly 256 entries
	mov eax, 1
	mov rdi, os_nvs_mem+0x4000
	add rdi, 14
virtio_scsi_init_pop2:
	mov [rdi], al
	add rdi, 16
	add al, 1
	cmp al, 0
	jne virtio_scsi_init_pop2

	; Set sizes
;	sense_size to 96
;	cdb_size to 32

	; 3.1.1 - Step 8 - At this point the device is “live”
	mov al, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_DRIVER_OK | VIRTIO_STATUS_FEATURES_OK
	mov [rsi+VIRTIO_DEVICE_STATUS], al

	; Check which LUNs exist
	; REPORT LUNS 0xA0 - 124
	mov rdi, cmd_cdb
	mov al, 0xa0
	stosb			; Operation Code
	mov al, 0x00
	stosb			; Select Report
	stosb			; Reserved
	stosb			; Reserved
	stosb			; Reserved
	stosb			; Reserved
	stosb			; Reserved
	stosb			; Reserved
	mov eax, 4096
	stosd
	mov al, 0x00
	stosb
	stosb

	call virtio_scsi_cmd

	; Check each LUN
	; INQUIRY 0x12 - 144

	; Verify each is ready
	; TEST UNIT READY 0x00 - 108

	; REQUEST SENSE 0x03 - 126

	; TEST UNIT READY 0x00 - 108

	; Check the capacity
	; READ CAPACITY (10) 0x25 - 116

	; MODE SENSE (10) 0x5A - 135

	; Read some data
	; READ (10) 0x28

jmp $
;	mov rcx, 1
;	mov rdi, 0x600000
;	call virtio_scsi_io
;	jmp virtio_scsi_init_error

virtio_scsi_init_done:
	bts word [os_nvsVar], 4	; Set the bit flag that Virtio SCSI has been initialized
	mov rdi, os_nvs_io		; Write over the storage function addresses
	mov eax, virtio_scsi_io
	stosq
	mov eax, virtio_scsi_id
	stosq
	pop rax
	pop rbx
	pop rdx
	pop rsi
	add rsi, 15
	mov byte [rsi], 1		; Mark driver as installed in Bus Table
	sub rsi, 15
	ret

virtio_scsi_init_error:
	pop rax
	pop rbx
	pop rdx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; virtio_scsi_cmd -- Perform a VIRTIO SCSI command
; IN:	TBD
; OUT:	Nothing
;	All other registers preserved
virtio_scsi_cmd:
	push r9
	push rdi
	push rdx
	push rcx
	push rbx
	push rax

	mov r9, rdi			; Save the memory address

	; Build the request
	; todo

	mov rdi, os_nvs_mem		; This driver always starts at beginning of the Descriptor Table
					; FIXME: Add desc_index offset
	add rdi, 16384

	; Add Request to Descriptor Entry 0
	mov rax, cmd			; Address of the request
	stosq				; 64-bit address
	mov eax, 51			; 19 byte REQ Header + 32 byte CDB
	stosd				; 32-bit length
	mov ax, VIRTQ_DESC_F_NEXT
	stosw				; 16-bit Flags
	add rdi, 2			; Skip Next as it is pre-populated

	; Add Response to Descriptor Entry 1
	mov rax, 0x600000		; Address of the response
	stosq				; 64-bit address
	mov eax, 108
	stosd				; 32-bit length
	mov eax, VIRTQ_DESC_F_NEXT | VIRTQ_DESC_F_WRITE
	stosw				; 16-bit Flags
	add rdi, 2			; Skip Next as it is pre-populated

	; Add data to Descriptor Entry 2
	mov rax, 0x610000		; Address to store the data
	stosq
	mov eax, 4096			; TODO remote hardcoded length
	stosd
	mov ax, VIRTQ_DESC_F_WRITE
	stosw				; 16-bit Flags
	add rdi, 2			; Skip Next as it is pre-populated

	; Add entry to Avail
	mov rdi, os_nvs_mem+0x5000	; Offset to start of Availability Ring
	mov ax, 1			; 1 for no interrupts
	stosw				; 16-bit flags
	mov ax, [availindex]
	stosw				; 16-bit index
	mov ax, 0
	stosw				; 16-bit ring

	; Notify the queue
	mov rdi, [os_virtioscsi_base]
	add rdi, [notify_offset]	; This driver only uses Queue 0 so no multiplier needed
	add rdi, 8
	xor eax, eax
	stosw

	; Inspect the used ring
	mov rdi, os_nvs_mem+0x6002	; Offset to start of Used Ring
	mov bx, [availindex]
virtio_scsi_cmd_wait:
	mov ax, [rdi]			; Load the index
	cmp ax, bx
	jne virtio_scsi_cmd_wait

	add word [descindex], 3		; 3 entries were required
	add word [availindex], 1

	pop rax
	pop rbx
	pop rcx
	pop rdx
	pop rdi
	pop r9
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; virtio_scsi_io -- Perform an I/O operation on a VIRTIO SCSI device
; IN:	RAX = starting sector #
;	RBX = I/O Opcode
;	RCX = number of sectors
;	RDX = drive #
;	RDI = memory location used for reading/writing data from/to device
; OUT:	Nothing
;	All other registers preserved
virtio_scsi_io:
	push r9
	push rdi
	push rdx
	push rcx
	push rbx
	push rax

	push rax			; Save the starting sector
	mov r9, rdi			; Save the memory address

	; Build the request
	; todo

	mov rdi, os_nvs_mem		; This driver always starts at beginning of the Descriptor Table
					; FIXME: Add desc_index offset
	add rdi, 16384

	; Add Request to Descriptor Entry 0
	mov rax, req			; Address of the request
	stosq				; 64-bit address
	mov eax, 51			; 19 byte REQ Header + 32 byte CDB
	stosd				; 32-bit length
	mov ax, VIRTQ_DESC_F_NEXT
	stosw				; 16-bit Flags
	add rdi, 2			; Skip Next as it is pre-populated

	; Add Response to Descriptor Entry 1
	mov rax, resp			; Address of the response
	stosq				; 64-bit address
	mov eax, 108
	stosd				; 32-bit length
	mov eax, VIRTQ_DESC_F_NEXT | VIRTQ_DESC_F_WRITE
	stosw				; 16-bit Flags
	add rdi, 2			; Skip Next as it is pre-populated

	; Add data to Descriptor Entry 2
	mov rax, r9			; Address to store the data
	stosq
	shl rcx, 12			; Covert count to 4096B sectors
	mov eax, ecx			; Number of bytes
	mov eax, 512			; TODO remote hardcoded length
	stosd
	mov ax, VIRTQ_DESC_F_WRITE
	stosw				; 16-bit Flags
	add rdi, 2			; Skip Next as it is pre-populated

;	; Build the header
;	mov rdi, header
;	; BareMetal I/O opcode for Read is 2, Write is 1
;	; Virtio-blk I/O opcode for Read is 0, Write is 1
;	; FIXME: Currently we just clear bit 1.
;	btc bx, 1
;	mov eax, ebx
;	stosd				; type
;	xor eax, eax
;	stosd				; reserved
	pop rax				; Restore the starting sector
;	shl rax, 3			; Multiply by 8 as we use 4096-byte sectors internally
;	stosq				; starting sector
;
;	; Build the footer
;	mov rdi, footer
;	xor eax, eax
;	stosb

	; Add entry to Avail
	mov rdi, os_nvs_mem+0x5000	; Offset to start of Availability Ring
	mov ax, 1			; 1 for no interrupts
	stosw				; 16-bit flags
	mov ax, [availindex]
	stosw				; 16-bit index
	mov ax, 0
	stosw				; 16-bit ring

	; Notify the queue
	mov rdi, [os_virtioscsi_base]
	add rdi, [notify_offset]	; This driver only uses Queue 0 so no multiplier needed
	add rdi, 8
	xor eax, eax
	stosw

	; Inspect the used ring
	mov rdi, os_nvs_mem+0x6002	; Offset to start of Used Ring
	mov bx, [availindex]
virtio_scsi_io_wait:
	mov ax, [rdi]			; Load the index
	cmp ax, bx
	jne virtio_scsi_io_wait

	add word [descindex], 3		; 3 entries were required
	add word [availindex], 1

	pop rax
	pop rbx
	pop rcx
	pop rdx
	pop rdi
	pop r9
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; virtio_scsi_id --
; IN:	EAX = CDW0
;	EBX = CDW1
;	ECX = CDW10
;	EDX = CDW11
;	RDI = CDW6-7
; OUT:	Nothing
;	All other registers preserved
virtio_scsi_id:
	ret
; -----------------------------------------------------------------------------

align 16
req: ; 19 bytes
;lun: db 0x01, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00
;id: dq 0x0000000000000000
;task_attr: db 0x00
;prio: db 0x00
;crn: db 0x00 ;

; 10-byte Command Descriptor Block
;cdb: db 0x28, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00

;blank: db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, ;0x00

align 16
cmd:
cmd_lun: db 0x01, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00
cmd_tag: dq 0
cmd_task_attr: db 0x00
cmd_prio: db 0x00
cmd_crn: db 0x00
cmd_cdb: db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

; 16-byte Command Descriptor Block
;cdb_opcode: db 0x28
;cdb_blank: db 0x00
;cdb_addr: dq 0x0000000000000000
;cdb_length: dd 0x00000001
;cdb_resv: db 0x00
;cdb_ctrl: db 0x00


; 32-byte Command Descriptor Block
;cdb_opcode: db 0x28
;cdb_ctrl: db 0x00
;cdb_misc1: db 0x00
;cdb_misc2: db 0x00
;cdb_misc3: db 0x00
;cdb_misc4: db 0x00
;cdb_misc5: db 0x00
;cdb_len: db 0x09
;cdb_srvact: dw 0x0000
;cdb_misc6: db 0x00
;cdb_misc7: db 0x00
;cdb_addr: dq 0x0000000000000000
;cdb_misc8: dq 0x0000000000000000
;cdb_length: dd 0x00000200


;cdb: db 0x28, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ;times 32 db 0x00

;align 16
resp:
;sense_len: dd 0x00000000
;residual: dd 0x00000000
;status_qualifier: dw 0x0000
;status: db 0x00
;response: db 0x00
;sense: times 96 db 0x00


; VIRTIO SCSI Registers - Device Config
; num_queues ; 32-bit
; seg_max ; 32-bit
; max_sectors ; 32-bit
; cmd_per_lun ; 32-bit
; event_info_size ; 32-bit
; sense_size ; 32-bit
; cdb_size ; 32-bit
; max_channel ; 16-bit
; max_target ; 16-bit
; max_lun ; 32-bit

; VIRTIO_DEVICEFEATURES bits
VIRTIO_SCSI_F_INOUT			equ 0 ; A single request can include both device-readable and device-writable data buffers
VIRTIO_SCSI_F_HOTPLUG			equ 1 ; The host SHOULD enable reporting of hot-plug and hot-unplug events for LUNs and targets on the SCSI bus. The guest SHOULD handle hot-plug and hot-unplug events.
VIRTIO_SCSI_F_CHANGE			equ 2 ; The host will report changes to LUN parameters via a VIRTIO_SCSI_T_-PARAM_CHANGE event; the guest SHOULD handle them
VIRTIO_SCSI_F_T10_PI			equ 3 ; The extended fields for T10 protection information (DIF/DIX) are included in the SCSI request header

; VIRTIO SCSI command-specific response values
VIRTIO_SCSI_S_OK			equ 0
VIRTIO_SCSI_S_OVERRUN			equ 1
VIRTIO_SCSI_S_ABORTED			equ 2
VIRTIO_SCSI_S_BAD_TARGET		equ 3
VIRTIO_SCSI_S_RESET			equ 4
VIRTIO_SCSI_S_BUSY			equ 5
VIRTIO_SCSI_S_TRANSPORT_FAILURE		equ 6
VIRTIO_SCSI_S_TARGET_FAILURE		equ 7
VIRTIO_SCSI_S_NEXUS_FAILURE		equ 8
VIRTIO_SCSI_S_FAILURE			equ 9

; =============================================================================
; EOF