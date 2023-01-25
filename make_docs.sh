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
dart doc --output $OUTPUT
cd lib
for f in `find . -name 'dartdoc' -print` ; do
    for g in $f/*; do
        lib=`basename $g`
        mkdir -p $OUTPUT/$lib/dartdoc/$lib/
        cp -r $g/* $OUTPUT/$lib/dartdoc/$lib/
        echo "    copied assets to $OUTPUT/$lib/dartdoc/$lib/"
    done
done
cd ..
if [ -e dartdoc ] ; then
    cp -r dartdoc $OUTPUT/
    echo "    copied assets to $OUTPUT/dartdoc"
fi
