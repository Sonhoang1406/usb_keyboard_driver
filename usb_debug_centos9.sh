#!/bin/bash

# USB Keyboard Debug Script for CentOS 9 on VMware
echo "=============================================="
echo "USB Keyboard Debug Tool - CentOS 9/VMware"
echo "=============================================="

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Step 1: Check USB subsystem
check_usb_system() {
    log_step "Checking USB subsystem..."
    
    echo "=== USB Controllers ==="
    lsusb -t 2>/dev/null || {
        log_warn "lsusb not found, installing..."
        sudo dnf install -y usbutils >/dev/null 2>&1
    }
    
    echo ""
    echo "=== All USB Devices ==="
    lsusb
    
    echo ""
    echo "=== USB Keyboards ==="
    USB_KEYBOARDS=$(lsusb | grep -i keyboard)
    if [ -n "$USB_KEYBOARDS" ]; then
        log_info "Found USB keyboards:"
        echo "$USB_KEYBOARDS"
    else
        log_warn "No USB keyboards detected by lsusb"
    fi
    
    echo ""
    echo "=== USB HID Devices ==="
    lsusb | grep -i hid || log_warn "No HID devices found"
}

# Step 2: Check input devices
check_input_devices() {
    log_step "Checking input devices..."
    
    echo "=== Input Event Devices ==="
    ls -la /dev/input/event* 2>/dev/null || log_warn "No event devices found"
    
    echo ""
    echo "=== Input Device Info ==="
    for dev in /dev/input/event*; do
        if [ -c "$dev" ]; then
            echo "Device: $dev"
            sudo file "$dev" 2>/dev/null || true
        fi
    done
    
    echo ""
    echo "=== Keyboard Devices ==="
    ls -la /dev/input/by-id/*keyboard* 2>/dev/null || log_warn "No keyboard devices in /dev/input/by-id/"
    
    echo ""
    echo "=== All Input Devices ==="
    cat /proc/bus/input/devices | grep -A 5 -B 5 -i keyboard || log_warn "No keyboards in /proc/bus/input/devices"
}

# Step 3: Check kernel modules
check_kernel_modules() {
    log_step "Checking kernel modules..."
    
    echo "=== USB Modules ==="
    lsmod | grep -E "(usb|hid)" | head -10
    
    echo ""
    echo "=== HID Modules ==="
    lsmod | grep hid
    
    echo ""
    echo "=== Input Modules ==="
    lsmod | grep input || log_warn "No input modules loaded"
    
    echo ""
    echo "=== USB HID Module Details ==="
    modinfo usbhid 2>/dev/null | head -10 || log_warn "usbhid module not found"
}

# Step 4: Check VMware Tools
check_vmware_tools() {
    log_step "Checking VMware Tools..."
    
    if command -v vmware-toolbox-cmd >/dev/null 2>&1; then
        log_info "VMware Tools installed"
        vmware-toolbox-cmd -v 2>/dev/null || true
        
        echo ""
        echo "=== VMware Status ==="
        vmware-toolbox-cmd stat sessionid 2>/dev/null || true
        vmware-toolbox-cmd stat speed 2>/dev/null || true
    else
        log_warn "VMware Tools not found - this may cause USB issues"
        log_info "Install with: sudo dnf install open-vm-tools"
    fi
    
    echo ""
    echo "=== VMware Kernel Modules ==="
    lsmod | grep -i vmware || log_warn "No VMware modules loaded"
}

# Step 5: Test keyboard input
test_keyboard_input() {
    log_step "Testing keyboard input..."
    
    echo "=== Available Input Devices ==="
    KEYBOARD_DEVICES=$(ls /dev/input/event* 2>/dev/null)
    
    if [ -z "$KEYBOARD_DEVICES" ]; then
        log_error "No input devices found!"
        return 1
    fi
    
    echo "Found devices:"
    echo "$KEYBOARD_DEVICES"
    
    echo ""
    log_info "Testing keyboard input (press Ctrl+C to stop)..."
    echo "Try pressing keys on your keyboard..."
    
    # Test each event device
    for device in $KEYBOARD_DEVICES; do
        echo ""
        echo "Testing device: $device"
        timeout 5s sudo cat "$device" 2>/dev/null && {
            log_info "Device $device is receiving input!"
            break
        } || {
            log_warn "No input detected on $device"
        }
    done
}

# Step 6: VMware specific checks
check_vmware_usb() {
    log_step "VMware USB specific checks..."
    
    echo "=== VMware USB Settings ==="
    log_info "Check these VMware settings:"
    echo "1. VM Settings → Hardware → USB Controller"
    echo "2. Enable 'USB 3.1' compatibility"
    echo "3. Enable 'Show all USB input devices'"
    echo "4. VM → Removable Devices → [Keyboard] → Connect"
    
    echo ""
    echo "=== USB Arbitrator Service ==="
    if systemctl is-active vmware-USBArbitrator >/dev/null 2>&1; then
        log_info "VMware USB Arbitrator is running"
    else
        log_warn "VMware USB Arbitrator not running"
    fi
    
    echo ""
    echo "=== Host vs Guest USB ==="
    log_warn "Common issues:"
    echo "• Host OS may be capturing USB device"
    echo "• Need to 'Connect' device in VMware menu"
    echo "• USB hub may not be supported"
    echo "• Try different USB port"
}

# Step 7: Suggested fixes
suggest_fixes() {
    log_step "Suggested fixes..."
    
    echo "=================================================="
    echo "USB KEYBOARD TROUBLESHOOTING STEPS"
    echo "=================================================="
    
    echo ""
    echo "🔧 VMWARE CONFIGURATION:"
    echo "1. VM Settings → Hardware → USB Controller"
    echo "   ✅ Enable USB 3.1"
    echo "   ✅ Show all USB input devices"
    echo ""
    echo "2. Connect USB device:"
    echo "   VM → Removable Devices → [Your Keyboard] → Connect"
    echo ""
    
    echo "💻 CENTOS 9 FIXES:"
    echo "3. Install/update VMware Tools:"
    echo "   sudo dnf install -y open-vm-tools"
    echo "   sudo systemctl enable vmtoolsd"
    echo "   sudo systemctl start vmtoolsd"
    echo ""
    echo "4. Load USB modules:"
    echo "   sudo modprobe usbhid"
    echo "   sudo modprobe usbkbd"
    echo ""
    echo "5. Check SELinux (if needed):"
    echo "   sudo setenforce 0  # Temporary"
    echo ""
    
    echo "🔄 ALTERNATIVE SOLUTIONS:"
    echo "6. Use VM's virtual keyboard:"
    echo "   VM → Send Ctrl+Alt+Del"
    echo ""
    echo "7. Enable SSH and connect remotely:"
    echo "   sudo systemctl enable sshd"
    echo "   sudo systemctl start sshd"
    echo "   # Then SSH from host"
    echo ""
    echo "8. USB passthrough (advanced):"
    echo "   - Add USB device to VM hardware"
    echo "   - Use USB 3.0/3.1 controller"
    echo ""
    
    echo "⚠️  TROUBLESHOOTING:"
    echo "9. If still not working:"
    echo "   • Try different USB port"
    echo "   • Restart VMware services"
    echo "   • Reboot both host and guest"
    echo "   • Use USB 2.0 instead of 3.1"
}

# Step 8: Quick fix script
quick_fix() {
    log_step "Applying quick fixes..."
    
    # Install VMware tools if not present
    if ! command -v vmware-toolbox-cmd >/dev/null 2>&1; then
        log_info "Installing VMware Tools..."
        sudo dnf install -y open-vm-tools >/dev/null 2>&1
        sudo systemctl enable vmtoolsd >/dev/null 2>&1
        sudo systemctl start vmtoolsd >/dev/null 2>&1
    fi
    
    # Load USB modules
    log_info "Loading USB modules..."
    sudo modprobe usbhid 2>/dev/null || true
    sudo modprobe usbkbd 2>/dev/null || true
    sudo modprobe usb_storage 2>/dev/null || true
    
    # Restart udev
    log_info "Restarting udev..."
    sudo systemctl restart systemd-udevd 2>/dev/null || true
    
    log_info "Quick fixes applied. Try connecting USB keyboard now."
}

# Main menu
show_menu() {
    echo ""
    echo "=============================================="
    echo "USB KEYBOARD DEBUG MENU"
    echo "=============================================="
    echo "1. Check USB system"
    echo "2. Check input devices"
    echo "3. Check kernel modules"
    echo "4. Check VMware Tools"
    echo "5. Test keyboard input"
    echo "6. VMware USB checks"
    echo "7. Show suggested fixes"
    echo "8. Apply quick fixes"
    echo "9. Full diagnostic"
    echo "0. Exit"
    echo "=============================================="
    read -p "Choose option [0-9]: " choice
}

# Full diagnostic
full_diagnostic() {
    log_step "Running full USB keyboard diagnostic..."
    check_usb_system
    echo ""
    check_input_devices
    echo ""
    check_kernel_modules
    echo ""
    check_vmware_tools
    echo ""
    check_vmware_usb
    echo ""
    suggest_fixes
}

# Main execution
main() {
    if [ "$1" == "auto" ]; then
        full_diagnostic
        exit 0
    fi
    
    if [ "$1" == "fix" ]; then
        quick_fix
        exit 0
    fi
    
    while true; do
        show_menu
        case $choice in
            1) check_usb_system ;;
            2) check_input_devices ;;
            3) check_kernel_modules ;;
            4) check_vmware_tools ;;
            5) test_keyboard_input ;;
            6) check_vmware_usb ;;
            7) suggest_fixes ;;
            8) quick_fix ;;
            9) full_diagnostic ;;
            0) exit 0 ;;
            *) log_error "Invalid option" ;;
        esac
        echo ""
        read -p "Press Enter to continue..."
    done
}

main "$@" 