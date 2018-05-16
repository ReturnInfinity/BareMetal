#!/bin/sh

CC=${CROSS_COMPILE}gcc
CFLAGS="${CFLAGS} -Wall -Wextra -Werror -Wfatal-errors"
CFLAGS="${CFLAGS} -std=gnu11"

AR=${CROSS_COMPILE}ar
ARFLAGS=rcs

${CC} ${CFLAGS} -c libBareMetal.c -o libBareMetal.o

${AR} ${ARFLAGS} libBareMetal.a libBareMetal.o
