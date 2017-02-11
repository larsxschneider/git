#!/bin/sh
#
# Perform sanity checks on documentation and build it.
#

set -e
set -x

make check-builtins
make check-docs

# Build docs with AsciiDoc
make clean
make --jobs=2 doc
grep '<meta name="generator" content="AsciiDoc ' Documentation/git.html
test -s Documentation/git.html
test -s Documentation/git.xml
test -s Documentation/git.1

cat Documentation/git.1


# Build docs with AsciiDoctor
make clean
make --jobs=2 doc USE_ASCIIDOCTOR=1
grep '<meta name="generator" content="Asciidoctor ' Documentation/git.html
test -s Documentation/git.html

cat Documentation/git.1
