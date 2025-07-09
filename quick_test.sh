#!/bin/bash

# Quick Build and Test Script for USB Keyboard Driver
echo "=== USB Keyboard Driver Quick Test ==="

# Step 1: Build the driver
echo "1. Building driver..."
make clean
make

if [ $? -ne 0 ]; then
    echo "ERROR: Build failed!"
    exit 1
fi

echo "✓ Build successful!"

# Step 2: Load the driver  
echo "2. Loading driver..."
sudo rmmod usbkbd 2>/dev/null  # Remove if already loaded
sudo insmod usbkbd.ko

if [ $? -eq 0 ]; then
    echo "✓ Driver loaded successfully!"
    sudo lsmod | grep usbkbd
else
    echo "ERROR: Failed to load driver!"
    exit 1
fi

# Step 3: Check status
echo "3. Checking driver status..."
sudo dmesg | tail -10

# Step 4: Test instructions
echo ""
echo "=== TEST INSTRUCTIONS ==="
echo "1. Open a text editor (vi, nano, gedit, etc.)"
echo "2. Try typing 'A' - it should output 'B'"
echo "3. Try typing 'B' - it should output 'A'"
echo "4. Other keys should work normally"
echo ""
echo "To test LEDs:"
echo "- Press NumLock/CapsLock/ScrollLock keys"
echo "- LEDs should respond according to driver logic"
echo ""
echo "To unload driver: sudo rmmod usbkbd"
echo "To monitor logs: sudo dmesg | tail -20"
echo ""
echo "Driver is now loaded and ready for testing!" 