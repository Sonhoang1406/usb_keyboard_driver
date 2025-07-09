#!/bin/bash

# Nạp module
echo "Nạp module..."
sudo insmod usbkbd.ko

# Đợi một lúc để đảm bảo module được nạp
sleep 1

# Bật/tắt LED
echo "Bật/tắt LED..."
sudo bash -c 'echo 1 > /sys/class/leds/usbkbd::numlock/brightness'
sleep 1
sudo bash -c 'echo 0 > /sys/class/leds/usbkbd::numlock/brightness'
sleep 1
sudo bash -c 'echo 1 > /sys/class/leds/usbkbd::capslock/brightness'
sleep 1
sudo bash -c 'echo 0 > /sys/class/leds/usbkbd::capslock/brightness'
sleep 1
sudo bash -c 'echo 1 > /sys/class/leds/usbkbd::scrolllock/brightness'
sleep 1
sudo bash -c 'echo 0 > /sys/class/leds/usbkbd::scrolllock/brightness'

# Kiểm tra log kernel
echo "Kiểm tra log kernel..."
sudo dmesg | tail -20

# Gỡ bỏ module
echo "Gỡ bỏ module..."
sudo rmmod usbkbd
sudo dmesg | tail -20

