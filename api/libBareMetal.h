// =============================================================================
// BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
// Copyright (C) 2008-2017 Return Infinity -- see LICENSE.TXT
//
// Version 1.0
// =============================================================================

#ifndef _LIBBAREMETAL_H
#define _LIBBAREMETAL_H

// Input/Output
unsigned char b_input(void);
void b_output(const char *str, unsigned long nbr);

// SMP
unsigned long b_smp_set(void *codeptr, void *dataptr, unsigned long cpu);
unsigned long b_smp_config();

// Memory
unsigned long b_mem_release(unsigned long *mem, unsigned long nbr);
unsigned long b_mem_allocate(unsigned long *mem, unsigned long nbr);

// Network
void b_ethernet_tx(void *mem, unsigned long len, unsigned long iid);
unsigned long b_ethernet_rx(void *mem, unsigned long iid);

// Disk
unsigned long b_disk_read(void *mem, unsigned long start, unsigned long num, unsigned long disknum);
unsigned long b_disk_write(void *mem, unsigned long start, unsigned long num, unsigned long disknum);

// Misc
unsigned long b_system_config(unsigned long function, unsigned long var);
void b_system_misc(unsigned long function, void *var1, void *var2);

// Index for b_system_config calls
#define TIMECOUNTER          0
#define NETWORKCALLBACK_GET  3
#define NETWORKCALLBACK_SET  4
#define CLOCKCALLBACK_GET    5
#define CLOCKCALLBACK_SET    6
#define MAC                  30

// Index for b_system_misc calls
#define SMP_GET_ID       1
#define SMP_LOCK         2
#define SMP_UNLOCK       3
#define DEBUG_DUMP_MEM   4
#define DEBUG_DUMP_RAX   5
#define DELAY            6
#define ETHERNET_STATUS  7
#define MEM_GET_FREE     8
#define SMP_NUMCORES     9
#define RESET            256

#endif


// =============================================================================
// EOF
