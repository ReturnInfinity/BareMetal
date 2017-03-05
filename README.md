# BareMetal-kernel

Official repo of the BareMetal [exokernel](http://en.wikipedia.org/wiki/Exokernel). It's written from scratch in Assembly, designed for x86-64 hardware, with no dependencies except for the virtual/physical hardware. A 64-bit ARMv8 version is also planned.


## What is this?

BareMetal is a _very_ lean kernel. The name is a play on the phrase "bare metal" which means to run directly on physical or virtualized hardware. BareMetal also only offers the "bare essentials" required for a working operating system.

BareMetal provides basic support for symetric multiprocessing, network, and disk access via a low-level abstraction layer.

![BareMetal Model](./doc/BareMetal-Model.png)


### Key features
* **64-bit**: Make use of the extra-wide and additional registers available in 64-bit mode.
* **Mono-processing, multi-core**: The system is able to execute a single "program" but can spread the work load amongst available CPU cores.
* **Extremely tiny memory footprint**: A minimal bootable image, including bootloader and operating system components, is currently 16K.
* **Standard C library** using [newlib](https://sourceware.org/newlib/) from [Red Hat](http://www.redhat.com/)
* **Physical and virtual hardware support** with full virtualization, using [x86 hardware virtualization](https://en.wikipedia.org/wiki/X86_virtualization) whenever available (it is on most modern x86-64 CPU's). In principle BareMetal should run on any x86-64 hardware platform, even on a physical x86-64 computer, given appropriate drivers. Officially, we develop on [QEMU](http://www.qemu.org) and [VirtualBox](https://www.virtualbox.org), which means that you can run BareMetal on both Linux, Microsoft Windows, and Apple macOS.


# Try it out!


## Prerequisites for building BareMetal

 * [NASM](http://www.nasm.us/) (The Netwide Assembler) - At least version 2.07
 * That's it!


## Editing BareMetal

[ATOM](https://atom.io/) is highly recommended. Make sure to install the [language-x86-64-assembly](https://atom.io/packages/language-x86-64-assembly) package for proper syntax highlighting.


## Building BareMetal

Execute the build script:

	./build_x86-64.sh


## Running BareMetal

Execute the run script to start the kernel in QEMU:

	./run_x86.64.sh


// EOF
