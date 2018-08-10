#!/bin/bash
set -e

./build.sh ultibonimprogram QEMUVPB

qemu-system-arm -M versatilepb -display none -vnc :70,websocket=5770 -cpu cortex-a8 -m 96M -kernel ultibo-nim-ultibonimprogram-kernel-QEMUVPB.img -serial stdio -usb -net nic -net user,hostfwd=tcp::5780-:80 -append "NETWORK0_IP_CONFIG=STATIC NETWORK0_IP_ADDRESS=10.0.2.15 NETWORK0_IP_NETMASK=255.255.255.0 NETWORK0_IP_GATEWAY=10.0.2.2 $(cat ultibo-nim-ultibonimprogram-cmdline.txt)"
