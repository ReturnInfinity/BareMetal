; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2015 Return Infinity -- see LICENSE.TXT
;
; System Call Section -- Accessible to user programs
; =============================================================================


%include "syscalls/debug.asm"
%include "syscalls/disk.asm"
%include "syscalls/input.asm"
%include "syscalls/memory.asm"
%include "syscalls/misc.asm"
%include "syscalls/net.asm"
%include "syscalls/screen.asm"
%include "syscalls/smp.asm"


; =============================================================================
; EOF
