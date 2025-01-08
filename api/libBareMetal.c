// =============================================================================
// BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
// Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
//
// Version 1.0
// =============================================================================


#include "libBareMetal.h"


// Input/Output

u8 b_input(void) {
	u8 chr;
	asm volatile ("call *0x00100010" : "=a" (chr));
	return chr;
}

void b_output(const char *str, u64 nbr) {
	asm volatile ("call *0x00100018" : : "S"(str), "c"(nbr));
}


// Network

void b_net_tx(void *mem, u64 len, u64 iid) {
	asm volatile ("call *0x00100020" : : "S"(mem), "c"(len), "d"(iid));
}

u64 b_net_rx(void *mem, u64 iid) {
	u64 tlong;
	asm volatile ("call *0x00100028" : "=c"(tlong) : "D"(mem), "d"(iid));
	return tlong;
}


// Storage

u64 b_storage_read(void *mem, u64 start, u64 num, u64 drivenum) {
	u64 tlong;
	asm volatile ("call *0x00100030" : "=c"(tlong) : "a"(start), "c"(num), "d"(drivenum), "D"(mem));
	return tlong;
}

u64 b_storage_write(void *mem, u64 start, u64 num, u64 drivenum) {
	u64 tlong = 0;
	asm volatile ("call *0x00100038" : "=c"(tlong) : "a"(start), "c"(num), "d"(drivenum), "S"(mem));
	return tlong;
}


// System

u64 b_system(u64 function, u64 var1, u64 var2) {
	u64 tlong;
	asm volatile ("call *0x00100040" : "=a"(tlong) : "c"(function), "a"(var1), "d"(var2));
	return tlong;
}


// =============================================================================
// EOF
