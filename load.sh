#!/bin/bash
sudo insmod usbkbd.ko
sudo dmesg | tail -20  # Kiểm tra thông điệp hệ thống

