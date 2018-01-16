#!/bin/sh
#
# Perform various static code analysis checks
#

. ${0%/*}/lib-travisci.sh

docker pull philmd/coccinelle:latest

docker run \
    --interactive \
    --volume "${PWD}:/usr/src/git" \
    --workdir /usr/src/git
    philmd/coccinelle:latest \
   make coccicheck

check_unignored_build_artifacts

save_good_tree

