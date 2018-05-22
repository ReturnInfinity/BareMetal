#!/bin/bash

opts=`getopt -o p:h --long arch:,path:,help -n "Install Options" -- "$@"`
if [ $? != 0 ]; then
	echo "Failed to parse install options."
	exit 1
fi

function print_help {
	echo "Options"
	echo "	-h, --help      : Print this help message."
	echo "	-a, --arch ARCH : Install the kernel of the specified architecture."
	echo "	-p, --path PATH : Install kernel files to specified path."
}

eval set -- ${opts}

help="false"
arch="x86-64"
path="${PWD}/output/system"

while true; do
	case "$1" in
		-h | --help ) print_help; exit 0;;
		-a | --arch ) arch="$2"; shift 2;;
		-p | --path ) path="$2"; shift 2;;
		-- ) shift; break;;
		* ) break;;
	esac
done

mkdir -p "${path}"
cp --update kernel.sys "${path}/kernel.sys"
cp --update kernel-debug.txt "${path}/kernel-debug.txt"
cp --update "src/${arch}/kernel.bin" "${path}/kernel.bin"
cp --update "src/${arch}/kernel.elf" "${path}/kernel.elf"
