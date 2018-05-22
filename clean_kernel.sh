#!/bin/bash

opts=`getopt -o a:h --long arch:,help -n "Clean Options" -- "$@"`
if [ $? != 0 ]; then
	echo "Failed to parse build options."
	exit 1
fi

function print_help {
	echo "Options"
	echo "	-h, --help      : Print this help message."
	echo "	-a, --arch ARCH : Clean files for specified architecture."
}

eval set -- ${opts}

help="false"
arch="x86-64"

while true; do
	case "$1" in
		-h | --help ) print_help; exit 0;;
		-a | --arch ) arch="$2"; shift 2;;
		-- ) shift; break;;
		* ) break;;
	esac
done

cd "src/$arch" && ./clean.sh && cd "../.."
