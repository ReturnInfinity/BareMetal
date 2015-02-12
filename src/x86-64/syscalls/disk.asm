; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2015 Return Infinity -- see LICENSE.TXT
;
; Disk Block Storage Functions
; =============================================================================


; -----------------------------------------------------------------------------
; os_disk_read -- 
; IN:	RAX = Starting block
;	RCX = Number of blocks
;	RDX = Disk 
;	RDI = Memory location to store data
; OUT:	
os_disk_read:

	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_disk_write -- 
; IN:	RAX = Starting block
;	RCX = Number of blocks
;	RDX = Disk 
;	RSI = Memory location of data
; OUT:	
os_disk_write:

	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
