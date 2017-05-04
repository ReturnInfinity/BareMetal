#!/bin/bash
# from http://unix.stackexchange.com/questions/9804/how-to-comment-multi-line-commands-in-shell-scripts

cmd=( qemu-system-x86_64
	-machine q35
	-cpu core2duo
# Text mode QEMU
	-curses
# Boot a multiboot kernel file
	-kernel ./boot.bin
# Enable GDB debugging
	-s
# Enable a supported NIC
	-net nic,model=e1000
# Amount of CPU cores
	-smp 2
# Amount of memory in Megabytes
	-m 256
# Disk configuration
	-drive id=disk,file=bmfs.image,if=none,format=raw
	-device ahci,id=ahci
	-device ide-drive,drive=disk,bus=ahci.0
#	-net dump,file=net.pcap
#	-serial file:serial.log
#	-monitor telnet:localhost:8086,server,nowait
)

#execute the cmd string
"${cmd[@]}"
