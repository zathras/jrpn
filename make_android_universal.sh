#!/bin/sh
cd `dirname $0`
rm -rf tmp.android
cd jrpn15
flutter clean
flutter build apk --release
if [ ! -e build/app/outputs/flutter-apk/app-release.apk ] ; then
    echo "Oops!"
    exit 1
fi
cd ..
cd jrpn16
flutter clean
flutter build apk --release
if [ ! -e build/app/outputs/flutter-apk/app-release.apk ] ; then
    echo "Oops!"
    exit 1
fi
cd ..

mkdir tmp.android
echo "made directory tmp.android"
mv jrpn16/build/app/outputs/flutter-apk/app-release.apk tmp.android/jrpn16_android_app-release.apk
mv jrpn15/build/app/outputs/flutter-apk/app-release.apk tmp.android/jrpn15_android_app-release.apk
