// =============================================================================
// BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
// Copyright (C) 2008-2017 Return Infinity -- see LICENSE.TXT
//
// Version 1.0
// =============================================================================


void b_output(const char *str) {
	asm volatile ("call *0x00100010" : : "S"(str)); // Make sure source register (RSI) has the string address (str)
}

void b_output_chars(const char *str, unsigned long nbr) {
	asm volatile ("call *0x00100018" : : "S"(str), "c"(nbr));
}


unsigned long b_input(unsigned char *str, unsigned long nbr) {
	unsigned long len;
	asm volatile ("call *0x00100020" : "=c" (len) : "c"(nbr), "D"(str));
	return len;
}

unsigned char b_input_key(void) {
	unsigned char chr;
	asm volatile ("call *0x00100028" : "=a" (chr));
	return chr;
}


unsigned long b_smp_set(void *codeptr, void *dataptr, unsigned long cpu) {
	unsigned long tlong;
	asm volatile ("call *0x00100030" : "=a"(tlong) : "a"(codeptr), "d"(dataptr), "c"(cpu));
	return tlong;
}

unsigned long b_smp_config() {
	return 0;
}


unsigned long b_mem_allocate(unsigned long *mem, unsigned long nbr) {
	unsigned long tlong;
	asm volatile ("call *0x00100040" : "=a"(*(mem)), "=c"(tlong) : "c"(nbr));
	return tlong;
}

unsigned long b_mem_release(unsigned long *mem, unsigned long nbr) {
	unsigned long tlong;
	asm volatile ("call *0x00100048" : "=c"(tlong) : "a"(*(mem)), "c"(nbr));
	return tlong;
}


void b_ethernet_tx(void *mem, unsigned long len, unsigned long iid) {
	asm volatile ("call *0x00100050" : : "S"(mem), "c"(len), "d"(iid));
}

unsigned long b_ethernet_rx(void *mem, unsigned long iid) {
	unsigned long tlong;
	asm volatile ("call *0x00100058" : "=c"(tlong) : "D"(mem), "d"(iid));
	return tlong;
}


unsigned long b_disk_read(void *mem, unsigned long start, unsigned long num, unsigned long disknum) {
	unsigned long tlong;
	asm volatile ("call *0x00100060" : "=c"(tlong) : "a"(start), "c"(num), "d"(disknum), "D"(mem));
	return tlong;
}

unsigned long b_disk_write(void *mem, unsigned long start, unsigned long num, unsigned long disknum) {
	unsigned long tlong = 0;
	asm volatile ("call *0x00100068" : "=c"(tlong) : "a"(start), "c"(num), "d"(disknum), "S"(mem));
	return tlong;
}


unsigned long b_system_config(unsigned long function, unsigned long var) {
	unsigned long tlong;
	asm volatile ("call *0x00100070" : "=a"(tlong) : "d"(function), "a"(var));
	return tlong;
}

void b_system_misc(unsigned long function, void* var1, void* var2) {
	asm volatile ("call *0x00100078" : : "d"(function), "a"(var1), "c"(var2));
}


// =============================================================================
// EOF
