// =============================================================================
// BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
// Copyright (C) 2008-2020 Return Infinity -- see LICENSE.TXT
//
// Version 1.0
// =============================================================================


#ifndef _LIBBAREMETAL_H
#define _LIBBAREMETAL_H

// Input/Output
unsigned char b_input(void);
void b_output(const char *str, unsigned long nbr);

// Network
void b_ethernet_tx(void *mem, unsigned long len, unsigned long iid);
unsigned long b_ethernet_rx(void *mem, unsigned long iid);

// Disk
unsigned long b_disk_read(void *mem, unsigned long start, unsigned long num, unsigned long disknum);
unsigned long b_disk_write(void *mem, unsigned long start, unsigned long num, unsigned long disknum);

// Misc
unsigned long b_config(unsigned long function, unsigned long var);
void b_system(unsigned long function, void *var1, void *var2);

// Index for b_config calls
#define TIMECOUNTER		0
#define SMP_GET_ID		1
#define NETWORKCALLBACK_GET	3
#define NETWORKCALLBACK_SET	4
#define CLOCKCALLBACK_GET	5
#define CLOCKCALLBACK_SET	6
#define MAC			30
#define PCI_READ		0x40
#define PCI_WRITE		0x41
#define STDOUT_SET		0x42
#define STDOUT_GET		0x43
#define DRIVE_ID		0x50

// Index for b_system calls
#define SMP_LOCK		2
#define SMP_UNLOCK		3
#define DEBUG_DUMP_MEM		4
#define DEBUG_DUMP_RAX		5
#define DELAY			6
#define ETHERNET_STATUS		7
#define MEM_GET_FREE		8
#define SMP_NUMCORES		9
#define SMP_SET			10
#define RESET			256

#endif


// =============================================================================
// EOF
