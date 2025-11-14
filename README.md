<div align="center">
<img src="doc/cheetah.svg" alt="BareMetal Logo" width="120" height="120">

# BareMetal
**Just enough kernel**

[![Assembly](https://img.shields.io/badge/x86--64-Assembly-blue)]()
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/ReturnInfinity/BareMetal/actions/workflows/main.yml/badge.svg)](https://github.com/ReturnInfinity/BareMetal/actions/workflows/main.yml)

<sub>Exokernel • Pure Assembly • Virtual/Physical</sub>
</div>

Official repo of the BareMetal [exokernel](http://en.wikipedia.org/wiki/Exokernel). It's written from scratch in Assembly, designed for x86-64 hardware, with no dependencies except for the virtual/physical hardware. An ARM and/or RISC-V rewrite would be considered once hardware is standardized.

### Table of Contents

- [What it is](#what-it-is)
- [Key features](#key-features)
- [Supported hardware](#supported-hardware)
- [Try it out](#try-it-out)

## What it is

BareMetal is a _very_ lean kernel. The name is a play on the phrase "bare metal" which means to run directly on physical or virtualized hardware. BareMetal also only offers the "bare essentials" required for a working operating system.

BareMetal provides basic support for symmetric multiprocessing, network, and storage access via a low-level abstraction layer.

![BareMetal Model](./doc/BareMetal-Model.png)


## Key features
* **64-bit**: Make use of the extra-wide and additional registers available in 64-bit mode.
* **Mono-processing, multi-core**: The system is able to execute a single program but can spread the work load amongst available CPU cores.
* **Extremely tiny memory footprint**: The kernel binary is less than 32KiB. BareMetal uses 4 MiB of RAM while running. The majority of RAM usage is for required memory structures for operating in 64-bit mode, drivers/system buffers, and CPU stacks.
* **Physical and virtual hardware support** with full virtualization, using [x86 hardware virtualization](https://en.wikipedia.org/wiki/X86_virtualization) whenever available (it is on most modern x86-64 CPU's). In principle BareMetal should run on any x86-64 hardware platform, even on a physical x86-64 computer, given appropriate drivers. Officially, we develop on [QEMU](http://www.qemu.org) and [VirtualBox](https://www.virtualbox.org), which means that you can run BareMetal on both Linux, Microsoft Windows, and Apple macOS.

## Supported Hardware

* CPU
  * Multi-core on 64-bit x86 systems (Intel/AMD)
* Bus
  * PCIe
  * PCI
  * xHCI (USB 3)
* Network
  * Gigabit
    * Intel 8254x Gigabit (e1000)
    * Intel 8257x Gigabit (e1000e)
  * 10 Gigabit
    * Intel 8259x 10 Gigabit (ixbge)
  * Virtual
    * Virtio-Net
* Storage
  * NVMe
  * AHCI (SATA)
  * Virtio-Blk
* HID (Human Interface Devices)
  * Input
    * PS/2 Keyboard
    * USB Keyboard
    * Serial
  * Output
    * LFB (linear frame buffer at native screen resolution with 1024x768x32bpp as fallback)
    * VGA text mode (80x25 characters with 16 colors)
    * Serial

## Try it out

See the [BareMetal-OS](https://github.com/ReturnInfinity/BareMetal-OS) repo for a full build environment.


// EOF
