#!/bin/sh
#
# Run dartdoc, and copy image assets.  The path for the image assets
# is long and redundant, but this allows the relative path to be consistent
# between the Dart source and the generated HTML.  That way, a developer
# reading the source in an IDE can easily find the images.
#

cd `dirname $0`
OUTPUT=`pwd`/docs/dartdoc
rm -rf $OUTPUT
echo "dart doc --output $OUTPUT"
ln -s `pwd`/jrpn15/lib shared/lib/jrpn15
ln -s `pwd`/jrpn16/lib shared/lib/jrpn16
dart doc --output $OUTPUT shared
if [ ! -e $OUTPUT/model ] ; then
    exit 1
fi
rm shared/lib/jrpn15
rm shared/lib/jrpn16

for d in  shared jrpn15 jrpn16  ; do
    cd $d
    for f in `find . -name 'dartdoc' -print` ; do
        for g in $f/*; do
            lib=`basename $g`
            mkdir -p $OUTPUT/$lib/dartdoc/$lib/
            cp -r $g/* $OUTPUT/$lib/dartdoc/$lib/
            echo "    copied assets to $OUTPUT/$lib/dartdoc/$lib/"
        done
    done
    cd ..
done
if [ -e dartdoc ] ; then
    cp -r dartdoc $OUTPUT/
    echo "    copied assets to $OUTPUT/dartdoc"
fi
