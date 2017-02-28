#!/bin/sh
#
# Build and test Git in a docker container running a 32-bit Ubuntu Linux
#

set -e

APT_INSTALL="apt update >/dev/null && apt install -y build-essential "\
"libcurl4-openssl-dev libssl-dev libexpat-dev gettext python >/dev/null"

TEST_GIT_ENV="DEFAULT_TEST_TARGET=$DEFAULT_TEST_TARGET "\
"GIT_PROVE_OPTS=\"$GIT_PROVE_OPTS\" "\
"GIT_TEST_OPTS=\"$GIT_TEST_OPTS\" "\
"GIT_TEST_CLONE_2GB=$GIT_TEST_CLONE_2GB"

TEST_GIT_CMD="linux32 --32bit i386 sh -c "\
"'$APT_INSTALL && cd /usr/src/git && $TEST_GIT_ENV make -j2 test'"

sudo docker run \
    --interactive --volume "${PWD}:/usr/src/git" \
    daald/ubuntu32:xenial /bin/bash -c "$TEST_GIT_CMD"
