#!/bin/bash
# from http://unix.stackexchange.com/questions/9804/how-to-comment-multi-line-commands-in-shell-scripts

cmd=( qemu-system-x86_64
	-machine q35
	-cpu core2duo
	-curses
	-kernel ./boot.bin
	-s
	-net nic,model=e1000
	-smp 2
	-m 256
#	-drive id=disk,file=bmfs.image,if=none,format=raw
#	-device ahci,id=ahci
#	-device ide-drive,drive=disk,bus=ahci.0
#	-net dump,file=net.pcap
#	-serial file:serial.log
#	-monitor telnet:localhost:1234,server,nowait
)

#execute the cmd string
"${cmd[@]}"
