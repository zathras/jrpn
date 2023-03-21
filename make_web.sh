#!/bin/sh -x
#
# Move the build web program to the website.  
#

cd `dirname $0`
cd jrpn15
flutter clean
flutter build web --release
if [ $? != 0 ]; then
    exit 1
fi
cd ../jrpn16
flutter clean
flutter build web --release
if [ $? != 0 ]; then
    exit 1
fi
cd ..
# rm -rf docs/run 
# mv jrpn16/build/web docs/run
rm -rf docs/run15
mv jrpn15/build/web docs/run15
