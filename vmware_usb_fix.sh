#!/bin/bash

# Quick VMware USB Keyboard Fix for CentOS 9
echo "=============================================="
echo "VMware USB Keyboard Quick Fix - CentOS 9"
echo "=============================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script needs root privileges for some operations"
    echo "Run: sudo $0"
    exit 1
fi

echo "🔧 Step 1: Installing VMware Tools..."
dnf install -y open-vm-tools open-vm-tools-desktop >/dev/null 2>&1
systemctl enable vmtoolsd >/dev/null 2>&1
systemctl start vmtoolsd >/dev/null 2>&1

echo "🔧 Step 2: Loading USB modules..."
modprobe usbhid 2>/dev/null || true
modprobe usbkbd 2>/dev/null || true
modprobe usb_storage 2>/dev/null || true

echo "🔧 Step 3: Restarting services..."
systemctl restart systemd-udevd 2>/dev/null || true

echo "🔧 Step 4: Checking current USB devices..."
echo "USB devices found:"
lsusb 2>/dev/null || echo "lsusb not available"

echo ""
echo "✅ Quick fixes applied!"
echo ""
echo "=============================================="
echo "NOW DO THESE VMWARE STEPS:"
echo "=============================================="
echo "1. 🔧 VM Settings → Hardware → USB Controller"
echo "   ✅ Set to 'USB 3.1'"
echo "   ✅ Check 'Show all USB input devices'"
echo ""
echo "2. 🔌 Connect your USB keyboard:"
echo "   VM → Removable Devices → [Your Keyboard] → Connect"
echo "   (Look for something like 'HID Keyboard Device')"
echo ""
echo "3. 🔍 Test detection:"
echo "   Run: lsusb | grep -i keyboard"
echo ""
echo "4. 📝 If still not working:"
echo "   chmod +x usb_debug_centos9.sh"
echo "   ./usb_debug_centos9.sh auto"
echo "==============================================" 