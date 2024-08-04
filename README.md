# BareMetal

_Just enough kernel_

Official repo of the BareMetal [exokernel](http://en.wikipedia.org/wiki/Exokernel). It's written from scratch in Assembly, designed for x86-64 hardware, with no dependencies except for the virtual/physical hardware. An ARM and/or RISC-V rewrite would be considered once hardware is standardized.


## What is this?

BareMetal is a _very_ lean kernel. The name is a play on the phrase "bare metal" which means to run directly on physical or virtualized hardware. BareMetal also only offers the "bare essentials" required for a working operating system.

BareMetal provides basic support for symmetric multiprocessing, network, and drive access via a low-level abstraction layer.

![BareMetal Model](./doc/BareMetal-Model.png)


### Key features
* **64-bit**: Make use of the extra-wide and additional registers available in 64-bit mode.
* **Mono-processing, multi-core**: The system is able to execute a single program but can spread the work load amongst available CPU cores.
* **Extremely tiny memory footprint**: A minimal bootable image, including boot-loader and operating system components, is currently 16K.
* **Physical and virtual hardware support** with full virtualization, using [x86 hardware virtualization](https://en.wikipedia.org/wiki/X86_virtualization) whenever available (it is on most modern x86-64 CPU's). In principle BareMetal should run on any x86-64 hardware platform, even on a physical x86-64 computer, given appropriate drivers. Officially, we develop on [QEMU](http://www.qemu.org) and [VirtualBox](https://www.virtualbox.org), which means that you can run BareMetal on both Linux, Microsoft Windows, and Apple macOS.


## Try it out!

See the [BareMetal-OS](https://github.com/ReturnInfinity/BareMetal-OS) repo for a full build environment.


// EOF
