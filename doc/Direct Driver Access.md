# Direct Driver Access

BareMetal is an exokernel so it allows a program to make calls directly to device drivers. This document deals only with network devices at the moment.

## Network

BareMetal has API functions for accessing network devices (`b_net_tx` and `b_net_rx`). These wrappers do some sanity checks, call the correct network interface drivers, and increment the relevant packet/byte counters.

API Example:

```
	mov rdx, 0		; Interface 0
	call [b_net_rx]		; Check for a packet
                                ; Returns the address of the data in RDI and the packet length in RCX
```

In some cases you may want to call a driver directly and skip the checks/counters.


### Network Poll

```
	mov rdx, 0		; Interface 0
	shl rdx, 7		; Quick multiply by 128
	add rdx, 0x11a000	; Offset to kernel network interface table

	; At this point the value in RDX can be saved for future usage

	call [rdx+0x28]		; Call the interface poll function
```

### Network Transmit

The code below depends on RDX being set correctly (like in the previous example).

```
  mov rsi, datalocation
  mov rcx, 1500
	call [rdx+0x20]		; Call the interface transmit function
```


// EOF
