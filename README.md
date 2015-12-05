BareMetal-kernel
================

Official repo of the BareMetal [exokernel](http://en.wikipedia.org/wiki/Exokernel)


What is this?
-------------

BareMetal is a _very_ lean kernel. The name is a play on the phrase "bare metal" which means to run your OS or application directly on hardware (without a virtualization layer). BareMetal also only offers the "bare essentials" required for a working operating system.

BareMetal provides basic hardware support for network and disk access via a low-level abstraction layer.


### Key features
* **Extremely tiny memory footprint**: A minimal bootable image, including bootloader and operating system components, is currently 16K.
* **Standard C library** using [newlib](https://sourceware.org/newlib/) from [Red Hat](http://www.redhat.com/)
* **Real hardware and VirtualBox support** with full virtualization, using [x86 hardware virtualization](https://en.wikipedia.org/wiki/X86_virtualization) whenever available (it is on most modern x86-64 CPU's). In principle BareMetal should run on any x86-64 hardware platform, even on a physical x86-64 computer, given appropriate drivers. Officially, we develop on [QEMU](http://www.qemu.org) and [VirtualBox](https://www.virtualbox.org), which means that you can run BareMetal on both Linux, Microsoft Windows, and Apple OS X. 

Try it out!
===========

Prerequisites for building BareMetal
------------------------------------

 * [NASM](http://www.nasm.us/) (The Netwide Assembler) - At least version 2.07
 * That's it!

Building BareMetal
------------------

Execute the build script:

	./build_x86-64.sh

Running BareMetal
-----------------

The easiest way to get started is with QEMU:

	qemu-system-x86_64 -machine q35 -cpu core2duo -smp 2 -m 1024 -kernel ./boot.bin -s



// EOF
