#!/bin/sh
set -x
REPO_SLUG=$1
BRANCH=$2

if test "$REPO_SLUG" = "larsxschneider/git"
then
    case "$BRANCH" in
        master) STABLE_BRANCH="maint";;
        next)   STABLE_BRANCH="master";;
        *)      STABLE_BRANCH="next";;
    esac
    cd ..
    git clone https://github.com/larsxschneider/git.git full
    cd full
    git remote add upstream https://github.com/git/git.git
    git fetch upstream
    git branch -a
    git remote -v
    git --version
    git rev-parse "$BRANCH"
    git rev-parse "upstream/$STABLE_BRANCH"
    GOOD_REV=$(git merge-base "$BRANCH" "upstream/$STABLE_BRANCH")
    echo "$GOOD_REV"
fi

for TEST_EXIT in t/test-results/*.exit
do
  if test "$(cat "$TEST_EXIT")" != "0"
  then
    TEST="${TEST_EXIT%.exit}"
    TEST_SCRIPT=${TEST#t/test-results/}
    TEST_OUT="${TEST}.out"
    echo "------------------------------------------------------------------------"
    echo "$(tput setaf 1)${TEST_OUT}...$(tput sgr0)"
    echo "------------------------------------------------------------------------"
    if test -n "$GOOD_REV"
    then
        git bisect start "$BRANCH" "$GOOD_REV"
        git bisect run sh -c "\
            if make --jobs=2 >/dev/null 2>&1;
            then cd t && ./$TEST_SCRIPT.sh --immediate >/dev/null 2>&1;
            else exit 125;
            fi"
        git bisect reset >/dev/null 2>&1
        echo ""
        echo "------------------------------------------------------------------------"
    fi
    cat "$TEST_OUT"
  fi
done
echo "done"
