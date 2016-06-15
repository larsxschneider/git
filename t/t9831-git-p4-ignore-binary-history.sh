#!/bin/sh

test_description='Ignore binary file history'

. ./lib-git-p4.sh

test_expect_success 'start p4d' '
	start_p4d
'

test_expect_success 'Create repo with binary files' '
	client_view "//depot/... //client/..." &&
	(
		cd "$cli" &&

		echo "bin content 1a">file.bin &&
		echo "txt content 1b">file.txt &&
		echo "t2b content 1c">file.t2b &&
		p4 add -t binary file.bin &&
		p4 add           file.txt &&
		p4 add           file.t2b &&
		p4 submit -d "rev1 - add all content 1" &&

		p4 edit file.bin &&
		echo "bin content 2">file.bin &&
		p4 submit -d "rev2 - edit bin content 2" &&

		p4 edit file.bin &&
		echo "bin content 3">file.bin &&
		p4 submit -d "rev3 - edit bin content 3" &&

		mkdir dir &&
		echo "bin content 4a">dir/subfile.bin &&
		echo "txt content 4b">dir/subfile.txt &&
		echo "t2b content 4c">dir/subfile.t2b &&
		p4 add -t binary dir/subfile.bin &&
		p4 add           dir/subfile.t2b &&
		p4 add           dir/subfile.txt &&
		p4 submit -d "rev4 - add sub content 4" &&

		p4 edit -t binary file.t2b &&
		p4 edit -t binary dir/subfile.t2b &&
		echo "t2b content 5a">file.t2b &&
		echo "t2b content 5b">dir/subfile.t2b &&
		p4 submit -d "rev5 - change file type from text to binary" &&

		p4 delete file.t2b &&
		p4 delete dir/subfile.t2b &&
		p4 submit -d "rev6 - delete files" &&

		p4 edit file.bin &&
		echo "bin content 7">file.bin &&
		p4 submit -d "rev7 - edit file"
	)
'

test_expect_success 'Ignore binary content before CL 2' '
	client_view "//depot/... //client/..." &&
	test_when_finished cleanup_git &&
	(
		cd "$git" &&
		git init . &&
		git config git-p4.useClientSpec true &&
		git config git-p4.ignoreBinaryFileHistoryBefore 2 &&
		git p4 clone --destination="$git" //depot@all &&

		cat >expect <<-\EOF &&
			rev7 - edit file
			[git-p4: depot-paths = "//depot/": change = 7]


			 file.bin | 2 +-
			 1 file changed, 1 insertion(+), 1 deletion(-)
			rev6 - delete files
			[git-p4: depot-paths = "//depot/": change = 6]


			 dir/subfile.t2b | 1 -
			 file.t2b        | 1 -
			 2 files changed, 2 deletions(-)
			rev5 - change file type from text to binary
			[git-p4: depot-paths = "//depot/": change = 5]


			 dir/subfile.t2b | 2 +-
			 file.t2b        | 2 +-
			 2 files changed, 2 insertions(+), 2 deletions(-)
			rev4 - add sub content 4
			[git-p4: depot-paths = "//depot/": change = 4]


			 dir/subfile.bin | 1 +
			 dir/subfile.t2b | 1 +
			 dir/subfile.txt | 1 +
			 3 files changed, 3 insertions(+)
			rev3 - edit bin content 3
			[git-p4: depot-paths = "//depot/": change = 3]


			 file.bin | 2 +-
			 1 file changed, 1 insertion(+), 1 deletion(-)
			rev2 - edit bin content 2
			[git-p4: depot-paths = "//depot/": change = 2]


			 file.bin | 1 +
			 1 file changed, 1 insertion(+)
			rev1 - add all content 1
			[git-p4: depot-paths = "//depot/": change = 1]

			Ignored binaries on git-p4 import:
			add: //depot/file.bin#1


			 file.t2b | 1 +
			 file.txt | 1 +
			 2 files changed, 2 insertions(+)
		EOF
		git log --format="%B" --stat >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'Ignore binary content before HEAD' '
	client_view "//depot/... //client/..." &&
	test_when_finished cleanup_git &&
	(
		cd "$git" &&
		git init . &&
		git config git-p4.useClientSpec true &&
		git config git-p4.ignoreBinaryFileHistoryBefore HEAD &&
		git p4 clone --destination="$git" //depot@all &&

		cat >expect <<-\EOF &&
			rev7 - edit file
			[git-p4: depot-paths = "//depot/": change = 7]


			 file.bin | 1 +
			 1 file changed, 1 insertion(+)
			rev6 - delete files
			[git-p4: depot-paths = "//depot/": change = 6]


			 dir/subfile.t2b | 1 -
			 file.t2b        | 1 -
			 2 files changed, 2 deletions(-)
			rev5 - change file type from text to binary
			[git-p4: depot-paths = "//depot/": change = 5]

			Ignored binaries on git-p4 import:
			edit: //depot/dir/subfile.t2b#2
			edit: //depot/file.t2b#2

			rev4 - add sub content 4
			[git-p4: depot-paths = "//depot/": change = 4]


			 dir/subfile.bin | 1 +
			 dir/subfile.t2b | 1 +
			 dir/subfile.txt | 1 +
			 3 files changed, 3 insertions(+)
			rev3 - edit bin content 3
			[git-p4: depot-paths = "//depot/": change = 3]

			Ignored binaries on git-p4 import:
			edit: //depot/file.bin#3

			rev2 - edit bin content 2
			[git-p4: depot-paths = "//depot/": change = 2]

			Ignored binaries on git-p4 import:
			edit: //depot/file.bin#2

			rev1 - add all content 1
			[git-p4: depot-paths = "//depot/": change = 1]

			Ignored binaries on git-p4 import:
			add: //depot/file.bin#1


			 file.t2b | 1 +
			 file.txt | 1 +
			 2 files changed, 2 insertions(+)
		EOF
		git log --format="%B" --stat >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'kill p4d' '
	kill_p4d
'

test_done
