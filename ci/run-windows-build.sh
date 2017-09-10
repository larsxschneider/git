#!/usr/bin/env bash
#
# Script to trigger the Git for Windows build and test run.
# Set the $GFW_CI_TOKEN as environment variable.
# Pass the branch (only branches on https://github.com/git/git are
# supported) and a commit hash.
#

. ${0%/*}/lib-travisci.sh

test $# -ne 2 && echo "Unexpected number of parameters" && exit 1
test -z "$GFW_CI_TOKEN" && echo "GFW_CI_TOKEN not defined" && exit

BRANCH=$1
COMMIT=$2
START=$(date +%s)
PREVIOUS_BUILD_IDS=$HOME/travis-cache/.vsts.build

gfwci () {
	local CURL_ERROR_CODE HTTP_CODE
	CONTENT_FILE=$(mktemp -t "git-windows-ci-XXXXXX")
	while test -z $HTTP_CODE
	do
	HTTP_CODE=$(curl \
		-H "Authentication: Bearer $GFW_CI_TOKEN" \
		--silent --retry 5 --write-out '%{HTTP_CODE}' \
		--output >(sed "$(printf '1s/^\xef\xbb\xbf//')" >$CONTENT_FILE) \
		"https://git-for-windows-ci.azurewebsites.net/api/TestNow?$1" \
	)
	CURL_ERROR_CODE=$?
		# The GfW CI web app sometimes returns HTTP errors of
		# "502 bad gateway" or "503 service unavailable".
		# We also need to check the HTTP content because the GfW web
		# app seems to pass through (error) results from other Azure
		# calls with HTTP code 200.
		# Wait a little and retry if we detect this error. More info:
		# https://docs.microsoft.com/en-in/azure/app-service-web/app-service-web-troubleshoot-http-502-http-503
		if test $HTTP_CODE -eq 502 ||
		   test $HTTP_CODE -eq 503 ||
		   grep "502 - Web server received an invalid response" $CONTENT_FILE >/dev/null
		then
			sleep 10
			HTTP_CODE=
		fi
	done
	cat $CONTENT_FILE
	rm $CONTENT_FILE
	if test $CURL_ERROR_CODE -ne 0
	then
		return $CURL_ERROR_CODE
	fi
	if test "$HTTP_CODE" -ge 400 && test "$HTTP_CODE" -lt 600
	then
		return 127
	fi
}

# Trigger build job
BUILD_ID=$(gfwci "action=trigger&branch=$BRANCH&commit=$COMMIT&skipTests=false")
if test $? -ne 0
then
	echo "Unable to trigger Visual Studio Team Services Build"
	echo "$BUILD_ID"
	exit 1
fi

# Check if the $BUILD_ID contains a number
case $BUILD_ID in
''|*[!0-9]*) echo "Unexpected build number: $BUILD_ID" && exit 1
esac

echo "Visual Studio Team Services Build #${BUILD_ID}"

# set -x
echo "928" > $PREVIOUS_BUILD_IDS
echo $BUILD_ID >> $PREVIOUS_BUILD_IDS

echo "--1"
cat $PREVIOUS_BUILD_IDS | tac
echo "--2"
cat $PREVIOUS_BUILD_IDS | tac | tail -n+1
echo "--3"
cat $PREVIOUS_BUILD_IDS | tac | tail -n+2
echo "--4"

# Wait until build job finished
STATUS=
RESULT=
IS_PREVIOUS_BUILD_ID=
while true
do
	LAST_STATUS=$STATUS
	if test $(($(date +%s) - $START)) -ge 0 # 9000 sec = 2.5h
	then
		printf "\n\nBuild #${BUILD_ID} hit the timeout. Checking previous builds ..."
		while read PREVIOUS
		do
			echo "AAAAAA xx$PREVIOUSxx"
			STATUS=$(gfwci "action=status&buildId=$PREVIOUS")
			echo "BBBBBB $STATUS"
			case "$STATUS" in
				 "completed: *")
					echo "#${PREVIOUS} completed!"
					BUILD_ID=$PREVIOUS
					IS_PREVIOUS_BUILD_ID=1
					break
					;;
			esac
		done < $PREVIOUS_BUILD_IDS | tac | tail -n+1
	else
		STATUS=$(gfwci "action=status&buildId=$BUILD_ID")
	fi

	test "$STATUS" = "$LAST_STATUS" || printf "\nStatus: %s " "$STATUS"
	printf "."

	case "$STATUS" in
	inProgress|postponed|notStarted) sleep 10               ;; # continue
		 "completed: succeeded") RESULT="success"; break;; # success
		    "completed: failed")                   break;; # failure
	*) echo "Unhandled status: $STATUS";               break;; # unknown
	esac
done

if test -n "$IS_PREVIOUS_BUILD_ID"
then
	echo "########################################################################"
	echo ""
	echo "     ATTENTION: The current build did not finish in time."
	echo "                The output is from a previous build that finished."
	echo ""
	echo "########################################################################"
else
	# The current build finished in time. Remove all previous builds.
	echo $BUILD_ID > $PREVIOUS_BUILD_IDS
fi

# Print log
echo ""
echo ""
gfwci "action=log&buildId=$BUILD_ID" | cut -c 30-

# Set exit code for TravisCI
test "$RESULT" = "success"
