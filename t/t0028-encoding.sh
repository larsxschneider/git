#!/bin/sh

test_description='encoding conversion via gitattributes'

. ./test-lib.sh

test_expect_success 'setup test repo' '

	text="hallo there!\ncan you read me?" &&

	echo "*.utf16 text encoding=utf-16" >.gitattributes &&
	printf "$text" >t.utf8.raw &&
	printf "$text" | iconv -f UTF-8 -t UTF-16 >t.utf16.raw &&
	cp t.utf16.raw t.utf16 &&

	git add .gitattributes t.utf16.raw t.utf16 &&
	git commit -m initial
'

test_expect_success 'ensure UTF-8 is stored in Git' '
	git cat-file -p :t.utf16 >t.utf16.git &&
	test_cmp_bin t.utf8.raw t.utf16.git
'

test_expect_success 're-encode to UTF-16 on checkout' '
	rm t.utf16 &&
	git checkout t.utf16 &&
	test_cmp_bin t.utf16.raw t.utf16
'

test_expect_success 'warn if an unsupported encoding is used' '
	echo "*.garbage text encoding=garbage" >>.gitattributes &&
	printf "garbage" >t.garbage &&
	git add t.garbage 2>error.out &&
	test_i18ngrep "warning: unsupported encoding" error.out &&

	# cleanup
	git reset --hard HEAD
'

test_expect_success 'fail if files with invalid encoding are added' '
	printf "\0\0h\0a" >error.utf16 &&
	# The test string encoding would fail
	# test_must_fail iconv -f utf-16 -t utf-8 error.utf16 &&
	test_must_fail git add error.utf16
'

# Some sequences might trigger errno == E2BIG in reencode_string_iconv, utf.8.
# This would cause no error on "git add" and, consequently, the Git internal
# UTF-8 encoded blob would contain garbage. Hence, the worktree file after a
# checkout would contain garbage, too. This garbage would not match the file
# that was initially added.
test_expect_success 'fail if encoding from X to UTF-8 and back to X is not the same' '
	printf "\xc3\x28" >error.utf16 &&
	# The test string re-encoding would fail
	# iconv -f utf-16 -t utf-8 error.utf16 | iconv -f utf-8 -t utf-16 &&
	test_must_fail git add error.utf16
'

test_done
