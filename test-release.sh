#!/bin/bash
set -x

rm -rf testing
mkdir testing
cp release/*.zip testing
pushd testing
unzip *.zip
rm *.zip
sudo cp ultibo-nim-ultibonimprogram-* config.txt /boot
df /boot
sleep 5
sudo reboot
