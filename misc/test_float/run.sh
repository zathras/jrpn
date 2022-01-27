#!/bin/sh
javac -cp apfloat.jar *.java
if [ $? != 0 ] ; then
    exit 1
fi
java -cp .:apfloat.jar TestFloat
