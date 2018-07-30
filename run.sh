#!/bin/bash
set -e

# on raspbian, build the program and reboot to it

./build.sh

set -x
sudo cp ultibo-nim-ultibonimprogram-kernel-RPI3.img /boot
sudo cp *-config.txt *-cmdline.txt /boot
sudo cp /boot/ultibo-nim-ultibonimprogram-config.txt /boot/config.txt

sleep 2
sudo reboot
