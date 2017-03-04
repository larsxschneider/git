#!/bin/sh

test_description='test log -L'
. ./test-lib.sh

test_expect_success 'setup (import history)' '
	git fast-import < "$TEST_DIRECTORY"/t4211/history.export &&
	git reset --hard
'

test_expect_success 'range_set_union' '
	which git &&
	git --version &&
	test_seq 500 > c.c &&
	git add c.c &&
	git commit -m "many lines" &&
	test_seq 1000 > c.c &&
	git add c.c &&
	git commit -m "modify many lines" &&
	git log $(for x in $(test_seq 200); do echo -L $((2*x)),+1:c.c; done)
'

test_done
