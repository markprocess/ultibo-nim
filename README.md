# ultibo-nim
[Ultibo](https://ultibo.org) [Features](https://ultibo.org/wiki/Current_Status#Feature_support) and [Nim](https://nim-lang.org)

Blinks the raspberry pi's activity led.

Try an rpi3b+ on-line at [ultibo-nim.iot.ngrok.io](http://ultibo-nim.iot.ngrok.io)

Try a vpb/qemu (with vnc too) [in the cloud](http://li1658-231.members.linode.com:5780)

[Prepare an sd card for your own pi](https://github.com/markprocess/ultibo-nim/releases)

## Raspbian Development Host Requirements

* [debian stretch lite](https://www.raspberrypi.org/downloads/raspbian/) installed on a raspberry pi
* [ultibo installed](https://ultibo.org/forum/viewtopic.php?f=4&t=887&p=5593&hilit=ultiboinstaller#p5593)
* [nim installed](https://nim-lang.org/install_unix.html) **Use Manual installation from source**

./run.sh - compiles the ultibo pascal main program and the nim library, creates the kernel.img
boot file and reboots to start the new kernel. The activity led should blink once per second. The new kernel
will have restored raspbian's /boot/config.txt so that recycling power will reboot to raspbian.

If the ultibo kernel does not work as expected, insert the sd card in a computer
and copy default-config.txt to config.txt to restore raspbian.

Two ring buffers are used between the main thread and the nim thread. One provides a millisecond clock
to the nim thread and one provides an led request to the main thread. The main thread supplies the clock
and changes the led based on requests. The nim thread reads the clock and requests led changes based on the time.

## Discussion

* [issues](https://github.com/markprocess/ultibo-nim/issues)
* [ultibo forum](https://ultibo.org/forum/search.php?keywords=ultibo-nim)
* [nim forum](https://forum.nim-lang.org/search?q=ultibo-nim)
