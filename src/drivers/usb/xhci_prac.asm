xhci_init:
    push rdx			; RDX should already point to a supported device for os_bus_read/write

	; Gather the Base I/O Address of the device
	mov al, 0			; Read BAR0
	call os_bus_read_bar
	mov [os_XHCI_Base], rax
	mov rsi, rax			; RSI holds the base for MMIO

	; Set PCI Status/Command values
	mov dl, 0x01			; Read Status/Command
	call os_bus_read
	bts eax, 10			; Set Interrupt Disable
	bts eax, 2			; Enable Bus Master
	bts eax, 1			; Enable Memory Space
	call os_bus_write		; Write updated Status/Command

	; Mark controller memory as un-cacheable
	mov rax, [os_XHCI_Base]
	shr rax, 18
	and al, 0b11111000		; Clear the last 3 bits
	mov rdi, 0x10000		; Base of low PDE
	add rdi, rax
	mov rax, [rdi]
	btc rax, 3			; Clear PWT to disable caching
	bts rax, 4			; Set PCD to disable caching
	mov [rdi], rax

	; Gather CAPLENGTH, check HCIVERSION, get offsets
	mov eax, [rsi+XHCI_CAPLENGTH]	; Read 4 bytes starting at CAPLENGTH
	mov [xhci_caplen], al		; Save the CAPLENGTH offset
	; Check for a valid version number
	shr eax, 16			; 16-bit version is in bits 31:16, shift to 15:0
	cmp ax, 0x0100			; Verify it is at least v1.0
	jl xhci_init_error

    ; /* Locate capability, operational, runtime, and doorbell registers */
    xor eax, eax
	mov al, [xhci_caplen]
	add rax, rsi			; RAX points to base of Host Controller Operational Registers
	mov [xhci_op], rax
	mov eax, [rsi+XHCI_DBOFF]	; Read the xHCI Doorbell Offset Register
	and eax, 0xFFFFFFFC		; Clear bits 1:0
	mov [xhci_db], rax
	mov eax, [rsi+XHCI_RTSOFF]	; Read the xHCI Runtime Register Base Offset Register
	and eax, 0xFFFFFFE0		; Clear bits 4:0
	mov [xhci_rt], rax



xhci_init_halt:
	mov rsi, [xhci_op]		; XHCI Operational Registers Base
	mov eax, [rsi+XHCI_USBCMD]	; Read current Command Register value
	bt eax, 0			; Check RS (bit 0)
	jnc xhci_init_reset		; If the bit was clear, proceed to reset
	btc eax, 0			; Clear RS (bit 0)
	mov [rsi+XHCI_USBCMD], eax	; Write updated Command Register value
	mov rax, 20000			; Wait 20ms (20000µs)
	call b_delay
	mov eax, [rsi+XHCI_USBSTS]	; Read Status Register
	bt eax, 0			; Check HCHalted (bit 0) - it should be 1
	jnc xhci_init_error		; Bail out if HCHalted wasn't cleared after 20ms
xhci_init_reset:
	mov eax, [rsi+XHCI_USBCMD]	; Read current Command Register value
	bts eax, 1			; Set HCRST (bit 1)
	mov [rsi+XHCI_USBCMD], eax	; Write updated Command Register value
	mov rax, 100000			; Wait 100ms (100000µs)
	call b_delay
	mov eax, [rsi+XHCI_USBSTS]	; Read Status Register
	bt eax, 11			; Check CNR (bit 11)
	jc xhci_init_error		; Bail out if CNR wasn't cleared after 100ms
	mov eax, [rsi+XHCI_USBCMD]	; Read current Command Register value
	bt eax, 1			; Check HCRST (bit 1)
	jc xhci_init_error		; Bail out if HCRST wasn't cleared after 100ms


    ; /* Get MaxSlots, Interrupters, and MaxPorts */
    mov eax, [rsi+XHCI_HCSPARAMS1]  ; Read HCSPARAMS1
    and eax, 0x000000FF             ; Extract MaxSlots (bits 7:0)
    mov byte [xhci_maxSlots], al           ; Store number of device slots

    mov eax, [rsi+XHCI_HCSPARAMS1]  ; Read HCSPARAMS1 again
    shr eax, 8                      ; Shift to get MaxIntrs (bits 17:8)
    and eax, 0x000003FF             ; Extract 10 bits for interrupters
    mov [xhci_max_intr], eax           ; Store number of interrupters

    mov eax, [rsi+XHCI_HCSPARAMS1]  ; Read HCSPARAMS1 again
    shr eax, 24                     ; Shift to get MaxPorts (bits 31:24)
    and eax, 0x000000FF             ; Extract MaxPorts value
    mov [os_XHCI_SLOT_ID], eax
    mov [xhci_maxPorts], eax           ; Store number of ports

    ; Get extended capabilities, Context Size and Page Size
    mov eax, [rsi + XHCI_HCCPARAMS1]    ; Read HCCPARAMS1 
    and eax, 0xFFFF0000                  ; Mask the lower 16 bits
    shr eax, 16                          ; Shift the result to the lower 16 bits
    imul eax, eax, 4                     ; Multiply eax by 4 (IMUL is signed, but we want unsigned)
    mov [xhci_ex_cap], eax               ; Store the extended capability pointer (32-bit)

    ; Get Context Size and Page Size
    mov eax, [rsi + XHCI_HCCPARAMS1]    ; Read HCCPARAMS1 
    test eax, 4                          ; Test bit 2 (Context Size bit)
    jz set_32_context                    ; Jump if context size is 32

    mov dword [xhci_context_size], 64   ; Set context size to 64 (if bit 2 is set)
    jmp xhci_get_page_size               ; Jump to page size handling

set_32_context:
    mov dword [xhci_context_size], 32            ; Set context size to 32 (if bit 2 is not set)

xhci_get_page_size:
    mov eax, [rsi + XHCI_PAGESIZE]       ; Read XHCI_PAGESIZE register
    and eax, 0x0000FFFF                  ; Mask to keep the lower 16 bits (page size)
    shl eax, 12                           ; Shift left by 12 (to scale the page size)
    mov [xhci_page_size], eax              ; Store the page size in xhci_page_size

;   Allocate DCBAA and CR
    mov rax, os_usb_DCI
    mov [xhci_m_dcbapp], rax

    mov rax, os_usb_CR
    mov [xhci_m_crcr], rax


    ; Get Scratch Pad buffers 
xhci_get_maxScratchpadBuffers:
    mov eax, [rsi + XHCI_HCSPARAMS2]    ; Read HCSPARAMS2
    shr eax, 27                         ; Shift to get the number of scratchpad buffers (bit 27:31)
    and eax, 0x1F                       ; Mask the lower 5 bits (number of scratchpad buffers)

    mov ebx, [rsi + XHCI_HCSPARAMS2]    ; Read HCSPARAMS2 again
    shr ebx, 16                         ; Shift to get the interruptors (bit 16:23)
    and ebx, 0xE0                       ; Mask the upper 3 bits for scratchpad buffer info

    and eax, ebx                        ; Perform a bitwise AND to get the final number of scratchpad buffers

    mov [xhci_max_scratchpadBuffers], eax  ; Store the number of scratchpad buffers in xhci_max_scratchpadBuffers


;   Scratch Pad Buffer Pointer Initialization to DCBAPP Left yet


;   Device Contexts Allocation per slot
    xor edx, edx 
    mov dl, byte [xhci_maxSlots]  ; Ensure EDX holds the correct max slot count
    mov ecx, 1                       ; Start from slot 1
    mov rdi, [xhci_m_dcbapp]          ; Base address of DCBAA
    mov rax, [os_usb_DCI]             ; Base address of Device Contexts

xhci_setup_device_contexts_loop:
    add rdi, 0x08       ; Move to the next DCBAA entry
    add rax, 0x800      ; Move to the next Device Context
    mov [rdi], rax      ; Store pointer to device context

    inc ecx
    cmp ecx, edx 
    jl xhci_setup_device_contexts_loop  ; Loop while ecx < edx (ensures correct termination)


; ;   Write to DCBAAP Resgiter to point DCBAPP
;     mov rsi, [xhci_op]
;     mov eax, [xhci_m_dcbapp]
;     mov [rsi+XHCI_DCBAPP], eax
;     xor rax, rax 
;     mov [rsi+0x34], rax 

; ;   Command Ring Link TRB
;     mov rdi, [xhci_m_crcr]
;     add rdi, 32640
    
;     mov rax, [xhci_m_crcr]   ; Load the base address of the command ring
;     mov [rdi+0x00], rax      ; Store it as the parameter field

;     mov dword [rdi+0x04], 0  ; Zero out field 2
;     mov dword [rdi+0x08], 0  ; Zero out field 3

;     mov eax, 0x06        ; Load TRB type (Link TRB)
;     and eax, 0x3f        ; And it with 0x3f
;     shl eax, 10          ; TRB_SET_TYPE(0x06) -> shift left by 10 (0x1800)
;     or  eax, (1 << 0)    ; TRB_CYCLE_ON (1 << 0)
;     or  eax, (1 << 4)    ; TRB_CHAIN_OFF (0 << 4) (No effect, can be removed)
;     or  eax, (1 << 5)    ; TRB_IOC_OFF (0 << 5) (No effect, can be removed)
;     mov [rdi+0x0C], eax  ; Store TRB command field

; ;   Write Command ring to CRCR
;     mov rsi, [xhci_op]
;     mov eax, [xhci_m_crcr]      ; Load Command ring
;     or eax, (1 << 0)            ; TRB Cycle On
;     mov [rsi+XHCI_CRCR], eax    ; Load to CRCR register
;     mov dword [rsi+0x0C], 0

;     mov dword [xhci_driver_crcr], xhci_m_crcr
;     mov dword [xhci_command_ring_enqueue], xhci_m_crcr
;     mov eax, (1 << 0)           ; TRB Cycle On
;     mov dword [xhci_command_ring_PCS], eax 


; ;   Configure Resgiter
;     mov rsi, [xhci_op]
;     xor eax, eax
; 	mov al, [xhci_maxSlots]
; 	mov [rsi+XHCI_CONFIG], eax

; ;   Device Notification Control (only bit 1 is allowed)
;     mov eax, 0x02         ; BIT(1)
;     mov [rsi+XHCI_DNCTRL], eax 

; Configure Event Ring for Primary Interrupter (Interrupt 0)
	mov rdi, [xhci_rt]
	add rdi, XHCI_IR_0		; Interrupt Register 0
	xor eax, eax			; Interrupt Enable (bit 1), Interrupt Pending (bit 0)
	stosd				; Interrupter Management Register (IMR)
	stosd				; Interrupter Moderation (IR)
	mov eax, 64
	stosd				; Event Ring Segment Table Size (ERSTS)
	add rdi, 4			; Skip Padding
	mov rax, os_usb_ERST
	; TODO - Load the register and preserve bits 5:0
	stosq				; Event Ring Segment Table Base Address (ERSTB)
	sub rax, os_usb_ER
	stosq				; Event Ring Dequeue Pointer (ERDP)
; ;   Start the Controller
;     mov rsi, [xhci_op]
;     mov eax, [rsi + XHCI_USBCMD]
;     bts eax, 2              ; Set INTE
;     mov [rsi + XHCI_USBCMD], eax 

;     mov eax, [rsi + XHCI_USBCMD]
;     bts eax, 3              ; Set HSEE
;     mov [rsi + XHCI_USBCMD], eax 

; ;   Clear the Status Register
;     mov eax, [rsi + XHCI_USBSTS]
;     or eax, (1 << 2) | (1 << 3) | (1 << 4) | (1 << 10)
;     mov [rsi + XHCI_USBSTS], eax

;     ; Start Controller
; 	mov eax, 0x01			; Set bits 0 (RS)
; 	mov [rsi+XHCI_USBCMD], eax


    jmp xhci_init_done

xhci_init_error:
	jmp $


xhci_init_done:    
    
    pop rdx
    ret




xhci_caplen:	db 0
; xhci_maxslots:	db 0    Replaced by xhci_slots
xhci_op:	dq 0			; Start of Operational Registers
xhci_db:	dq 0			; Start of Doorbell Registers
xhci_rt:	dq 0			; Start of Runtime Registers

; New From checking LibOS code
xhci_maxSlots:    dd 0  ; Number of device slots
xhci_max_intr:    dd 0  ; Number of interrupters
xhci_maxPorts:    dd 0  ; Number of ports
xhci_context_size:              dd 0    ; Context Size
xhci_page_size :                dd 0    ; Page Size 
xhci_ex_cap:      dd 0  ; Extended Capabilities  Pointer
xhci_max_scratchpadBuffers:     db 0    ; Maximum ScratchPad Buffers 
xhci_m_dcbapp:    dd 0
xhci_m_crcr:      dd 0
xhci_driver_crcr:               dd 0 
xhci_command_ring_enqueue:      dd 0
xhci_command_ring_PCS:          dd 0
xhci_m_ers:       dd 0
xhci_m_erst:      dd 0
xhci_current_event_ring_address:    dd 0
xhci_segment_table:             dd 0
; -----------------------------------------------------------------------------

; Memory (to be redone)
os_usb:			equ 0x0000000000680000	; 0x680000 -> 0x69FFFF	128K USB Structures
os_usb_DCI:		equ 0x0000000000680000	; 0x680000 -> 0x6807FF	2K Device Context Index
os_usb_DC0:		equ 0x0000000000680800	; 2K Device Context 0
os_usb_DC1:		equ 0x0000000000681000	; 2K Device Context 1
os_usb_DC2:		equ 0x0000000000681800	; 2K Device Context 2
os_usb_DC3:		equ 0x0000000000682000	; 2K Device Context 3
os_usb_DC4:		equ 0x0000000000682800	; 2K Device Context 4
os_usb_DC5:		equ 0x0000000000683000	; 2K Device Context 5
os_usb_DC6:		equ 0x0000000000683800	; 2K Device Context 6
os_usb_DC7:		equ 0x0000000000684000	; 2K Device Context 7

os_usb_CR:		equ 0x0000000000690000	; 0x690000 -> 0x69FFFF	64K Command Ring
os_usb_ER:		equ 0x00000000006A0000	; 0x6A0000 -> 0x6AFFFF	64K Event Ring 
os_usb_ERST:		equ 0x00000000006B0000	; 
os_segment_table:   equ 0x0000000000710000
os_usb_scratchpad:	equ 0x0000000000720000


; Register list

; Host Controller Capability Registers (Read-Only)
XHCI_CAPLENGTH	equ 0x00	; 1-byte Capability Registers Length
XHCI_HCIVERSION	equ 0x02	; 2-byte Host Controller Interface Version Number
XHCI_HCSPARAMS1	equ 0x04	; 4-byte Structural Parameters 1
XHCI_HCSPARAMS2	equ 0x08	; 4-byte Structural Parameters 2
XHCI_HCSPARAMS3	equ 0x0C	; 4-byte Structural Parameters 3
XHCI_HCCPARAMS1	equ 0x10	; 4-byte Capability Parameters 1
XHCI_DBOFF	equ 0x14	; 4-byte Doorbell Offset
XHCI_RTSOFF	equ 0x18	; 4-byte Runtime Registers Space Offset
XHCI_HCCPARMS2	equ 0x1C	; 4-byte Capability Parameters 2 (XHCI v1.1+)
XHCI_VTIOSOFF	equ 0x20	; 4-byte VTIO Register Space Offset (XHCI v1.2+)

; Host Controller Operational Registers (Starts at XHCI_Base + CAPLENGTH)
XHCI_USBCMD	equ 0x00	; 4-byte USB Command Register
XHCI_USBSTS	equ 0x04	; 4-byte USB Status Register
XHCI_PAGESIZE	equ 0x08	; 4-byte Page Size Register (Read-Only)
XHCI_DNCTRL	equ 0x14	; 4-byte Device Notification Control Register
XHCI_CRCR	equ 0x18	; 8-byte Command Ring Control Register
XHCI_DCBAPP	equ 0x30	; 8-byte Device Context Base Address Array Pointer Register
XHCI_CONFIG	equ 0x38	; 4-byte Configure Register

; Host Controller USB Port Register Set (Starts at XHCI_Base + CAPLENGTH + 0x0400 - 16 bytes per port)
XHCI_PORTSC	equ 0x00	; 4-byte Port Status and Control Register
XHCI_PORTPMSC	equ 0x04	; 4-byte Port PM Status and Control Register
XHCI_PORTLI	equ 0x08	; 4-byte Port Link Info Register (Read-Only)
XHCI_PORTHLPMC	equ 0x0C	; 4-byte Port Hardware LPM Control Register

; Host Controller Doorbell Register Set (Starts at XHCI_Base + CAPLENGTH + DBOFF)
XHCI_CDR	equ 0x00	; 4-byte Command Doorbell Register (Target bits 7:0)
XHCI_DS1	equ 0x04	; 4-byte Device Slot #1 Doorbell
XHCI_DS2	equ 0x08	; 4-byte Device Slot #2 Doorbell

; Host Controller Runtime Register Set (Starts at XHCI_Base + CAPLENGTH + RTSOFF)
XHCI_MICROFRAME	equ 0x00	; 4-byte Microframe Index Register
; Microframe is incremented every 125 microseconds. Each frame (1ms) is 8 microframes
; 28-bytes padding
XHCI_IR_0	equ 0x20	; 32-byte Interrupter Register Set 0
XHCI_IR_1	equ 0x40	; 32-byte Interrupter Register Set 1

; Interrupter Register Set
XHCI_IR_IMR	equ 0x00	; 4-byte Interrupter Management Register
XHCI_IR_IM	equ 0x04	; 4-byte Interrupter Moderation
XHCI_IR_ERSTS	equ 0x08	; 4-byte Event Ring Segment Table Size
; 4-byte padding
XHCI_IR_ERSTB	equ 0x10	; 8-byte Event Ring Segment Table Base Address
XHCI_IR_ERDP	equ 0x18	; 8-byte Event Ring Dequeue Pointer

; =============================================================================
; EOF