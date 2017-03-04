#!/bin/sh
#
# Build and test Git in a docker container running a 32-bit Ubuntu Linux
#
# Usage:
#   run-linux32-build.sh [container-image]
#

CONTAINER="${1:-daald/ubuntu32:xenial}"

sudo docker run --interactive --volume "${PWD}:/usr/src/git" "$CONTAINER" \
    /bin/bash -c 'linux32 --32bit i386 sh -c "
    : update packages &&
    apt update >/dev/null &&
    apt install -y build-essential libcurl4-openssl-dev libssl-dev \
	libexpat-dev gettext python >/dev/null &&

    : build and test &&
    cd /usr/src/git &&
    make --jobs=2 &&
    cd t &&
    timeout 60 ./t4211-line-log.sh -v -x
"'
