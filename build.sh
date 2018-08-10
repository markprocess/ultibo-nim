#!/bin/bash
set -e

REPO=ultibo-nim
LPR=$1
CONF=$2

if [[ $LPR == "" ]]
then
    LPR=ultibonimprogram
fi

if [[ $CONF == "" ]]
then
    CONF=RPI3
fi

echo build.sh $LPR $CONF
case $CONF in
QEMUVPB)
    PROC=QEMUVPB
    ARCH=ARMV7a
    KERNEL=kernel.bin
    ;;
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
set +e
uname -a | grep ' armv7l '
ARM=$?
set -e
if [[ $ARM == 0 ]]
then
    nim c -f --cpu:arm --app:staticlib --noMain --os:standalone --gc:none -d:release ultibonimlib.nim
else
    nim c -c -f --cpu:arm --noMain --os:standalone --gc:none -d:release ultibonimlib.nim
    cat << __EOF__ >> ~/.cache/ultibonimlib_r/ultibonimlib.c
    void systemInit000(void)
    {
    }
    void systemDatInit000(void)
    {
    }
    void stdlib_volatileInit000(void)
    {
    }
    void stdlib_volatileDatInit000(void)
    {
    }
__EOF__
    arm-none-eabi-gcc -O2 -mabi=aapcs -marm -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard -D__DYNAMIC_REENT__ -I/root/.choosenim/toolchains/nim-#devel/lib -c ~/.cache/ultibonimlib_r/ultibonimlib.c
    arm-none-eabi-ar rcs libultibonimlib.a ultibonimlib.o
fi
fpc -dBUILD_$CONF -B -O2 -Tultibo -Parm -Cp$ARCH -Wp$PROC -Fi$ULTIBO/source/rtl/ultibo/extras -Fi$ULTIBO/source/rtl/ultibo/core @$ULTIBOBIN/$CONF.CFG $LPR.lpr |& tee errors.log

mv $KERNEL $REPO-$LPR-kernel-$CONF.img
