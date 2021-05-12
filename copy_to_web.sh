#!/bin/zsh -x
#
# Build the web version, and copy it to freeshell.de.

cd `dirname $0`
flutter build web
if [ $? != 0 ] ; then
    exit 1
fi
ssh $EBU rm -rf public_html/jrpn
scp -r build/web $EBU:public_html/jrpn
ssh $EBU chmod a+rx public_html/jrpn
ssh $EBU find public_html/jrpn -type f -exec chmod a+r {} '\;'
ssh $EBU find public_html/jrpn -type d -exec chmod a+rx {} '\;'
