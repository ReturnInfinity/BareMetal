// =============================================================================
// BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
// Copyright (C) 2008-2020 Return Infinity -- see LICENSE.TXT
//
// Version 1.0
// =============================================================================


unsigned char b_input(void) {
	unsigned char chr;
	asm volatile ("call *0x00100010" : "=a" (chr));
	return chr;
}

void b_output(const char *str, unsigned long nbr) {
	asm volatile ("call *0x00100018" : : "S"(str), "c"(nbr));
}


void b_ethernet_tx(void *mem, unsigned long len, unsigned long iid) {
	asm volatile ("call *0x00100020" : : "S"(mem), "c"(len), "d"(iid));
}

unsigned long b_ethernet_rx(void *mem, unsigned long iid) {
	unsigned long tlong;
	asm volatile ("call *0x00100028" : "=c"(tlong) : "D"(mem), "d"(iid));
	return tlong;
}


unsigned long b_disk_read(void *mem, unsigned long start, unsigned long num, unsigned long disknum) {
	unsigned long tlong;
	asm volatile ("call *0x00100030" : "=c"(tlong) : "a"(start), "c"(num), "d"(disknum), "D"(mem));
	return tlong;
}

unsigned long b_disk_write(void *mem, unsigned long start, unsigned long num, unsigned long disknum) {
	unsigned long tlong = 0;
	asm volatile ("call *0x00100038" : "=c"(tlong) : "a"(start), "c"(num), "d"(disknum), "S"(mem));
	return tlong;
}


unsigned long b_config(unsigned long function, unsigned long var) {
	unsigned long tlong;
	asm volatile ("call *0x00100040" : "=a"(tlong) : "c"(function), "a"(var));
	return tlong;
}

void b_system(unsigned long function, void* var1, void* var2) {
	asm volatile ("call *0x00100048" : : "c"(function), "a"(var1), "d"(var2));
}


// =============================================================================
// EOF
