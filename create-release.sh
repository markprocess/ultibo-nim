#!/bin/bash
set -e # exit script on any error

RELEASE_COUNTER=2
VERSION=v$(date +%Y%m%d)-r$RELEASE_COUNTER
PREFIX=ultibo-nim
ZIPFILE=$PREFIX-$VERSION.zip
PATH=$HOME/hub-linux-arm-2.3.0-pre10/bin:$PATH

mkdir -p release
rm -rf release/*

rm -f *kernel*.img
for LPR in ultibonimprogram
do
    for CONF in RPI RPI2 RPI3
    do
        ./build.sh $LPR $CONF
    done
done
set -x
cp -a *.img release/
cp -a $PREFIX-*-config.txt $PREFIX-*-cmdline.txt release/
cp -a release/$PREFIX-ultibonimprogram-config.txt release/config.txt
echo "$PREFIX $VERSION" >> release/release-message.md
echo >> release/release-message.md
cat release-message.md >> release/release-message.md
cp -a firmware/boot/bootcode.bin firmware/boot/start.elf firmware/boot/fixup.dat release/
cd release
zip $ZIPFILE *
ls -lt $ZIPFILE
cd ..

#hub release create -d -p -F release/release-message.md -a release/$ZIPFILE $VERSION
