#!/bin/bash

qemu-system-x86_64 \
	-machine q35 \
	-cpu core2duo \
	-curses \
#	-drive id=disk,file=bmfs.image,if=none,format=raw \
#	-device ahci,id=ahci \
#	-device ide-drive,drive=disk,bus=ahci.0 \
	-name "BareMetal"
	-kernel ./boot.bin \
	-s \
	-net nic,model=e1000 \
#	-net dump,file=net.pcap \
#	-serial file:serial.log \
	-smp 2 \
	-m 256
