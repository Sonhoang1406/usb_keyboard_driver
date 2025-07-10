#!/bin/bash

# ============================================
# USB Keyboard Driver - CentOS 9 Setup Master
# ============================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=============================================="
echo "USB Keyboard Driver - CentOS 9 Setup"
echo "=============================================="

# Make all scripts executable
echo -e "${BLUE}[SETUP]${NC} Making scripts executable..."
chmod +x *.sh 2>/dev/null || true

# List available scripts
echo ""
echo -e "${GREEN}Available Commands:${NC}"
echo "=============================================="
echo ""
echo "🚀 QUICK START (Recommended):"
echo "   sudo ./centos9_quick_test.sh"
echo ""
echo "⚡ FIX DRIVER PRIORITY ISSUES:"
echo "   sudo ./quick_fix_driver.sh       # One command fix"
echo "   sudo ./fix_keyboard_driver.sh auto  # Full diagnostic"
echo ""
echo "🔧 FULL TEST SUITE:"
echo "   sudo ./centos9_build_test.sh auto"
echo ""
echo "📋 INTERACTIVE MENU:"
echo "   sudo ./centos9_build_test.sh"
echo ""
echo "📚 LEGACY SUPPORT (CentOS 6):"
echo "   sudo ./quick_test.sh          # Old quick test"
echo "   sudo ./build_and_test.sh      # Old full test"
echo ""
echo "🔍 MANUAL COMMANDS:"
echo "   make clean && make             # Build only"
echo "   sudo insmod usbkbd.ko          # Load driver"
echo "   sudo rmmod usbkbd              # Unload driver"
echo "   dmesg | tail -20               # View logs"
echo ""
echo "🩺 DEBUGGING TOOLS:"
echo "   ./usb_debug_centos9.sh auto    # USB debug"
echo "   ./fix_keyboard_driver.sh status  # Driver status"
echo ""
echo "=============================================="

# Show system info
echo ""
echo -e "${YELLOW}System Information:${NC}"
echo "OS: $(cat /etc/redhat-release 2>/dev/null || uname -o)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"

# Check if this is CentOS 9
if grep -q "CentOS Stream release 9\|Red Hat Enterprise Linux release 9" /etc/redhat-release 2>/dev/null; then
    echo -e "${GREEN}✓ CentOS 9 detected - Use centos9_* scripts${NC}"
    echo ""
    echo "Quick start command:"
    echo -e "${BLUE}sudo ./centos9_quick_test.sh${NC}"
elif grep -q "CentOS release 6\|CentOS Linux release 6" /etc/redhat-release 2>/dev/null; then
    echo -e "${YELLOW}⚠ CentOS 6 detected - Use legacy scripts${NC}"
    echo ""
    echo "Quick start command:"
    echo -e "${BLUE}sudo ./quick_test.sh${NC}"
else
    echo -e "${YELLOW}⚠ Unknown OS - Try centos9_* scripts first${NC}"
    echo ""
    echo "Recommended command:"
    echo -e "${BLUE}sudo ./centos9_quick_test.sh${NC}"
fi

echo ""
echo "=============================================="
echo "📖 For detailed instructions, see:"
echo "   • README_CentOS9.md    (CentOS 9 guide)"
echo "   • README.md            (Legacy CentOS 6)"
echo "==============================================" 