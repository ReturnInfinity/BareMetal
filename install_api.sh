#!/bin/bash

opts=`getopt -o i:l:h --long include_path:,library_path:,help -n "Install Options" -- "$@"`
if [ $? != 0 ]; then
	echo "Failed to parse install options."
	exit 1
fi

function print_help {
	echo "Options"
	echo "	-h, --help               : Print this help message."
	echo "	-i, --include_path PATH  : Install header to specified path."
	echo "	-l, --library_path PATH  : Install library to specified path."
}

eval set -- ${opts}

help="false"
libpath="${PWD}/output/lib"
incpath="${PWD}/output/include"

while true; do
	case "$1" in
		-h | --help ) print_help; exit 0;;
		-i | --include-path ) incpath="$2"; shift 2;;
		-l | --library-path ) libpath="$2"; shift 2;;
		-- ) shift; break;;
		* ) break;;
	esac
done

mkdir -p "${libpath}"
mkdir -p "${incpath}"
cp --update "api/libBareMetal.a" "${libpath}/libBareMetal.a"
cp --update "api/libBareMetal.h" "${incpath}/libBareMetal.h"
