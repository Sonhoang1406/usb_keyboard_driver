#!/bin/bash

# Quick Driver Priority Fix - One Command Solution
echo "🔧 Quick Fix: Forcing custom keyboard driver to work..."

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "❌ Need root: sudo $0"
    exit 1
fi

# Build if needed
if [ ! -f "usbkbd.ko" ]; then
    echo "📦 Building driver..."
    make clean && make || { echo "❌ Build failed"; exit 1; }
fi

# Unload conflicting drivers
echo "🗑️  Unloading built-in drivers..."
rmmod hid_generic 2>/dev/null || true
rmmod usbhid 2>/dev/null || true
rmmod usbkbd 2>/dev/null || true

# Load custom driver
echo "🚀 Loading custom driver..."
if insmod usbkbd.ko; then
    echo "✅ Custom driver loaded!"
    lsmod | grep usbkbd
    
    echo ""
    echo "🎯 TEST NOW:"
    echo "   vi test.txt"
    echo "   Press 'A' → Should show 'B'"
    echo "   Press 'B' → Should show 'A'"
    echo ""
    echo "📊 Monitor: sudo dmesg -w | grep usbkbd"
else
    echo "❌ Failed to load driver!"
    dmesg | tail -5
    exit 1
fi 