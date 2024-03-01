// =============================================================================
// BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
// Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
//
// Version 1.0
// =============================================================================


#ifndef _LIBBAREMETAL_H
#define _LIBBAREMETAL_H

// Input/Output
unsigned char b_input(void);
void b_output(const char *str, unsigned long nbr);

// Network
void b_net_tx(void *mem, unsigned long len, unsigned long iid);
unsigned long b_net_rx(void *mem, unsigned long iid);

// Storage
unsigned long b_storage_read(void *mem, unsigned long start, unsigned long num, unsigned long drivenum);
unsigned long b_storage_write(void *mem, unsigned long start, unsigned long num, unsigned long drivenum);

// Misc
unsigned long b_config(unsigned long function, unsigned long var);
void b_system(unsigned long function, void *var1, void *var2);

// Index for b_config calls
#define TIMECOUNTER		0x00
#define SMP_GET_ID		0x01
#define NETWORKCALLBACK_GET	0x03
#define NETWORKCALLBACK_SET	0x04
#define CLOCKCALLBACK_GET	0x05
#define CLOCKCALLBACK_SET	0x06
#define SCREEN_LFB_GET		0x20
#define SCREEN_X_GET		0x21
#define SCREEN_Y_GET		0x22
#define SCREEN_BPP_GET		0x23
#define MAC_GET			0x30
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
#define NET_STATUS		7
#define MEM_GET_FREE		8
#define SMP_NUMCORES		9
#define SMP_SET			10
#define RESET			256

#endif


// =============================================================================
// EOF
