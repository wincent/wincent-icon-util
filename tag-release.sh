#!/bin/sh -e
# Copyright 2009-2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

#
# Configuration
#

TAG_NAME='wincent-icon-util'
LONG_TAG_NAME='Wincent Icon Utility'

#
# Functions
#

die()
{
  echo "fatal: $1"
  exit 1
}

#
# Main
#

test $# -eq 1 || die "expected 1 parameter (the version number), received $#"
VERSION=$1
PREFIX=$(git rev-parse --show-prefix)
test -z "$PREFIX" || die "not at top of working tree"

echo "Preview:"
echo "  git tag -s $VERSION -m \"$VERSION release\" in $(pwd)"

/bin/echo -n "Enter yes to continue: "
read CONFIRM
if [ "$CONFIRM" = "yes" ]; then
  git tag -s $VERSION -m "$VERSION release"
fi
