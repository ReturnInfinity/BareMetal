; Multiboot for BareMetal/Pure64

; http://stackoverflow.com/questions/33488194/creating-a-simple-multiboot-kernel-loaded-with-grub2
; https://www.gnu.org/software/grub/manual/multiboot/multiboot.html#OS-image-format

[BITS 32]
[global _start]
[ORG 0x100000]		;If using '-f bin' we need to specify the
			;origin point for our code with ORG directive
			;multiboot loaders load us at physical
			;address 0x100000

FLAG_ALIGN		equ 1<<0   ; align loaded modules on page boundaries
FLAG_MEMINFO		equ 1<<1   ; provide memory map
FLAG_AOUT_KLUDGE	equ 1<<16
			;FLAGS[16] indicates to GRUB we are not
			;an ELF executable and the fields
			;header address, load address, load end address;
			;bss end address and entry address will be available
			;in Multiboot header

MAGIC			equ 0x1BADB002
			;magic number GRUB searches for in the first 8k
			;of the kernel file GRUB is told to load

FLAGS			equ FLAG_AOUT_KLUDGE | FLAG_ALIGN | FLAG_MEMINFO
CHECKSUM		equ -(MAGIC + FLAGS)

mode_type		equ 1
width			equ 1024
height			equ 768
depth			equ 32

_start:				; We need some code before the multiboot header
	xor eax, eax		; Clear eax and ebx in the event
	xor ebx, ebx		; we are not loaded by GRUB.
	jmp multiboot_entry	; Jump over the multiboot header
	align 4			; Multiboot header must be 32-bit aligned

multiboot_header:
	dd MAGIC		; magic
	dd FLAGS		; flags
	dd CHECKSUM		; checksum
	dd multiboot_header	; header address
	dd _start		; load address of code entry point
	dd 0x00			; load end address : not necessary
	dd 0x00			; bss end address : not necessary
	dd multiboot_entry	; entry address GRUB will start at

align 16

multiboot_entry:
	push 0
	popf

; Copy memory map
	mov esi, ebx		; GRUB stores the Multiboot info table at the address in EBX
	mov edi, 0x4000		; We want the memory map stored here
	add esi, 44		; Memory map address at this offset in the Mutliboot table
	lodsd			; Grab the memory map size in bytes
	mov ecx, eax
	lodsd			; Grab the memory map address
	mov esi, eax

memmap_entry:
	lodsd			; Size of entry
	cmp eax, 0
	je memmap_end
	movsd			; base_addr_low
	movsd			; base_addr_high
	movsd			; length_low
	movsd			; length_high
	movsd			; type
	xor eax, eax
	stosd			; padding
	stosd
	stosd
	jmp memmap_entry

memmap_end:
	xor eax, eax
	mov ecx, 8
	rep stosd

; Copy loader and kernel to expected location
	mov esi, multiboot_end
	mov edi, 0x00008000
	mov ecx, 8192		; Copy 32K
	rep movsd		; Copy loader to expected address

	cli

	jmp 0x00008000

times 512-$+$$ db 0			; Padding

multiboot_end:

; =============================================================================
; EOF
