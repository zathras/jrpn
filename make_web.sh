#!/bin/sh -x
#
# Move the build web program to the website.  This assumes
# "flutter build web" has successfully been run on both jrpn15
# and jrpn16.
#

cd `dirname $0`
rm -rf docs/run docs/run15
mv jrpn15/build/web docs/run15
mv jrpn16/build/web docs/run
