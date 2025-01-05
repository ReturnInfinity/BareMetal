// =============================================================================
// BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
// Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
//
// Version 1.0
// =============================================================================

// Headers
#include <stdint.h> // For uint*_t
#ifndef _LIBBAREMETAL_H
#define _LIBBAREMETAL_H

// Typedefs
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;

// Input/Output
u8 b_input(void);
void b_output(const char *str, u64 nbr);

// Network
void b_net_tx(void *mem, u64 len, u64 iid);
u64 b_net_rx(void *mem, u64 iid);

// Storage
u64 b_storage_read(void *mem, u64 start, u64 num, u64 drivenum);
u64 b_storage_write(void *mem, u64 start, u64 num, u64 drivenum);

// System
u64 b_system(u64 function, u64 var1, u64 var2);

// Index for b_config calls
#define TIMECOUNTER		0x00
#define FREE_MEMORY		0x01
#define GET_MOUSE		0x02
#define SMP_ID			0x10
#define SMP_NUMCORES		0x11
#define SMP_SET			0x12
#define SMP_GET			0x13
#define SMP_LOCK		0x14
#define SMP_UNLOCK		0x15
#define SMP_BUSY		0x16
#define TSC			0x1F
#define SCREEN_LFB_GET		0x20
#define SCREEN_X_GET		0x21
#define SCREEN_Y_GET		0x22
#define SCREEN_PPSL_GET		0x23
#define SCREEN_BPP_GET		0x24
#define MAC_GET			0x30
#define BUS_READ		0x50
#define BUS_WRITE		0x51
#define STDOUT_SET		0x52
#define STDOUT_GET		0x53
#define CALLBACK_TIMER		0x60
#define CALLBACK_NETWORK	0x61
#define CALLBACK_KEYBOARD	0x62
#define CALLBACK_MOUSE		0x63
#define DUMP_MEM		0x70
#define DUMP_RAX		0x71
#define DELAY			0x72
#define RESET			0x7D
#define REBOOT			0x7E
#define SHUTDOWN		0x7F

#endif


// =============================================================================
// EOF
