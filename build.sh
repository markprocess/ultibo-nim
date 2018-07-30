#!/bin/bash
set -e

REPO=ultibo-nim
LPR=ultibonimprogram
CONF=RPI3

echo build.sh $LPR $CONF
case $CONF in
RPI)
    PROC=RPIB
    ARCH=ARMV6
    KERNEL=kernel.img
    ;;
RPI2)
    PROC=RPI2B
    ARCH=ARMV7a
    KERNEL=kernel7.img
    ;;
RPI3)
    PROC=RPI3B
    ARCH=ARMV7a
    KERNEL=kernel7.img
    ;;
esac

ULTIBO=$HOME/ultibo/core
ULTIBOBIN=$ULTIBO/fpc/bin
export PATH=$ULTIBOBIN:$PATH
for f in *.lpr
do
    ptop -l 1000 -i 1 -c ptop.cfg $f $f.formatted
    mv $f.formatted $f
done

rm -rf lib/ *.o libultibonimlib.a
nim c --app:staticlib --noMain --os:standalone --gc:none -d:release ultibonimlib.nim
fpc -dBUILD_$CONF -B -O2 -Tultibo -Parm -Cp$ARCH -Wp$PROC -Fi$ULTIBO/source/rtl/ultibo/extras -Fi$ULTIBO/source/rtl/ultibo/core @$ULTIBOBIN/$CONF.CFG $LPR.lpr |& tee errors.log

mv $KERNEL $REPO-$LPR-kernel-$CONF.img
