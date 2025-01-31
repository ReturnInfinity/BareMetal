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

    ; /* Get MaxSlots, Interrupters, and MaxPorts */
    mov eax, [rsi+XHCI_HCSPARAMS1]  ; Read HCSPARAMS1
    and eax, 0x000000FF             ; Extract MaxSlots (bits 7:0)
    mov [xhci_maxSlots], eax           ; Store number of device slots

    mov eax, [rsi+XHCI_HCSPARAMS1]  ; Read HCSPARAMS1 again
    shr eax, 8                      ; Shift to get MaxIntrs (bits 17:8)
    and eax, 0x000003FF             ; Extract 10 bits for interrupters
    mov [xhci_max_intr], eax           ; Store number of interrupters

    mov eax, [rsi+XHCI_HCSPARAMS1]  ; Read HCSPARAMS1 again
    shr eax, 24                     ; Shift to get MaxPorts (bits 31:24)
    and eax, 0x000000FF             ; Extract MaxPorts value
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
    mov [os_XHCI_SLOT_ID], eax             ; Store page size in os_XHCI_SLOT_ID
    mov [xhci_page_size], eax              ; Store the page size in xhci_page_size

    ; Allocate DCBAA,CRCR and the Slot Contexts.
    mov rdi, 4096         ; Size (4096 bytes)
    mov rsi, 64           ; Alignment (64 bytes)
    mov rdx, xhci_page_size         ; Page size (4096 bytes)
    call simple_malloc
    mov [xhci_m_dcbapp], rax  ; Store the pointer to the DCBAA in xhci_dcbapp

    mov rdi, 256 * 64  ; Size for CRCR
    mov rsi, 64                    ; Alignment (64 bytes)
    mov rdx, 65536                 ; Page size (65536 bytes)
    call simple_malloc
    mov [xhci_m_crcr], rax           ; Store the pointer to the CRCR in xhci_crcr


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



    jmp xhci_init_done

xhci_init_error:
	jmp $


xhci_init_done:    
    
    pop rdx
    ret





; =============================================================================
; Simple Malloc for Memory Allocation
; Arguments:
;   rdi - bytes to allocate (size in bytes)
;   rsi - alignment (in bytes)
;   rdx - page boundary (in bytes, typically 0x1000 for 4KB)
; =============================================================================
simple_malloc:
;     ; Ensure rdi (bytes) is non-zero, if zero, return null
;     test rdi, rdi
;     jz malloc_error

;     ; Load the current heap pointer
;     mov rax, [current_heap]
    
;     ; Align to the specified alignment boundary
;     ; Align the current heap pointer to the given alignment (rsi)
;     sub rax, 1                    ; Decrease rax by 1
;     add rax, rsi                  ; Add the alignment (rsi) to rax
;     not rsi                       ; Invert rsi to prepare for alignment mask
;     and rax, rsi                  ; Align it down to the boundary
    
;     ; Now, ensure it is also aligned to the page boundary (rdx)
;     sub rax, 1                    ; Decrease rax by 1 to align it to page boundary
;     add rax, rdx                  ; Add page size (rdx)
;     not rdx                       ; Invert rdx to prepare for alignment mask
;     and rax, rdx                  ; Align it to page boundary

;     ; Check if the allocated memory exceeds the pool size
;     add rbx, rdi                  ; Add size to the current address
;     cmp rbx, MEMORY_POOL_START + MEMORY_POOL_SIZE
;     jg malloc_error               ; If out of memory, jump to error

;     ; Update the current heap pointer to the new location
;     mov [current_heap], rbx

;     ; Return the allocated memory address in rax
;     ret

; malloc_error:
;     ; Return null (zero) on error (out of memory)
;     xor rax, rax
;     ret


; ; Increase the size of the memory pool (For os_malloc)
; MEMORY_POOL_START    equ 0x10000000      ; Start of the memory pool (still at 0x680000)
; MEMORY_POOL_SIZE     equ 0x800000      ; Increase to 8MB

; current_heap         dq MEMORY_POOL_START ; Keep track of the current position in the pool
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
xhci_context_size:  dd 0    ; Context Size
xhci_page_size :    dd 0    ; Page Size 
xhci_ex_cap:      dd 0  ; Extended Capabilities  Pointer
xhci_max_scratchpadBuffers:     db 0    ; Maximum ScratchPad Buffers 
xhci_m_dcbapp:    dq 0
xhci_m_crcr:      dq 0 

; -----------------------------------------------------------------------------


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