#!/bin/bash
# from http://unix.stackexchange.com/questions/9804/how-to-comment-multi-line-commands-in-shell-scripts

cmd=( qemu-system-x86_64
	-machine q35
	-cpu core2duo
# Text mode QEMU
	-curses
# Boot a multiboot kernel file
	-kernel ./boot.bin
# Enable a supported NIC
	-device e1000,netdev=net0
	-netdev user,id=net0
# Amount of CPU cores
	-smp 2
# Amount of memory in Megabytes
	-m 256
# Disk configuration
	-drive id=disk,file=bmfs.image,if=none,format=raw
	-device ahci,id=ahci
	-device ide-drive,drive=disk,bus=ahci.0
# Ouput network to file
#	-net dump,file=net.pcap
# Output serial to file
#	-serial file:serial.log
# Enable monitor mode
#	-monitor telnet:localhost:8086,server,nowait
# Enable GDB debugging
#	-s
# Wait for GDB before starting execution
#	-S
)

#execute the cmd string
"${cmd[@]}"
