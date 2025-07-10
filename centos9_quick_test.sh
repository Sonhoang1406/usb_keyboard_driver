#!/bin/bash

# Quick Test Script for CentOS 9 USB Keyboard Driver
echo "=============================================="
echo "CentOS 9 USB Keyboard Driver - Quick Test"
echo "=============================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script needs root privileges${NC}"
    echo "Usage: sudo $0"
    exit 1
fi

# Step 1: Quick dependency check
echo -e "${GREEN}[1/5]${NC} Checking dependencies..."
if ! command -v gcc >/dev/null 2>&1; then
    echo "Installing build tools..."
    dnf install -y gcc make kernel-devel >/dev/null 2>&1
fi

# Step 2: Build driver
echo -e "${GREEN}[2/5]${NC} Building driver..."
make clean >/dev/null 2>&1
if make >/dev/null 2>&1; then
    echo "✓ Build successful: $(ls -lh usbkbd.ko | awk '{print $5}')"
else
    echo -e "${RED}✗ Build failed!${NC}"
    echo "Error details:"
    make
    exit 1
fi

# Step 3: Load driver
echo -e "${GREEN}[3/5]${NC} Loading driver..."
rmmod usbkbd 2>/dev/null || true
if insmod usbkbd.ko; then
    echo "✓ Driver loaded successfully"
    lsmod | grep usbkbd
else
    echo -e "${RED}✗ Failed to load driver${NC}"
    dmesg | tail -5
    exit 1
fi

# Step 4: System info
echo -e "${GREEN}[4/5]${NC} System information..."
echo "Kernel: $(uname -r)"
echo "USB Keyboards: $(lsusb | grep -c -i keyboard || echo 0)"
echo "Input devices: $(ls /dev/input/event* 2>/dev/null | wc -l || echo 0)"

# Step 5: Test instructions
echo -e "${GREEN}[5/5]${NC} Test instructions:"
echo ""
echo "=============================================="
echo "TESTING GUIDE"
echo "=============================================="
echo "1. Open text editor:"
echo "   vi test.txt    (or nano test.txt)"
echo ""
echo "2. Test key swapping:"
echo "   • Press 'A' → Should type 'B'"
echo "   • Press 'B' → Should type 'A'"
echo "   • Other keys work normally"
echo ""
echo "3. Test LEDs (if available):"
echo "   setleds +num    # NumLock on"
echo "   setleds -num    # NumLock off"
echo "   setleds +caps   # CapsLock on"
echo "   setleds -caps   # CapsLock off"
echo ""
echo "4. Monitor logs:"
echo "   dmesg | tail -20"
echo ""
echo "5. Unload driver:"
echo "   sudo rmmod usbkbd"
echo ""
echo "=============================================="
echo "✓ Driver ready for testing!"
echo "=============================================="

# Monitor initial logs
echo ""
echo "Recent kernel messages:"
dmesg | tail -10 