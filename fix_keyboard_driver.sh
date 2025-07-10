#!/bin/bash

# Fix Keyboard Driver Priority - Force Custom Driver to Work
echo "=============================================="
echo "Keyboard Driver Priority Fix - CentOS 9"
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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script needs root privileges"
    echo "Run: sudo $0"
    exit 1
fi

# Step 1: Check current driver status
check_current_status() {
    log_step "Checking current driver status..."
    
    echo "=== Custom Driver Status ==="
    if lsmod | grep -q "^usbkbd "; then
        log_info "Custom usbkbd driver is loaded:"
        lsmod | grep "^usbkbd "
    else
        log_warn "Custom usbkbd driver NOT loaded"
    fi
    
    echo ""
    echo "=== Built-in Drivers Status ==="
    echo "USB HID driver:"
    lsmod | grep "^usbhid " || log_warn "usbhid not loaded"
    
    echo "HID Generic driver:"
    lsmod | grep "^hid_generic " || log_warn "hid_generic not loaded"
    
    echo "Input core:"
    lsmod | grep "^input_core " || lsmod | grep "input" | head -3
    
    echo ""
    echo "=== Active Input Devices ==="
    cat /proc/bus/input/devices | grep -A 3 -B 1 -i keyboard || log_warn "No keyboards found in /proc/bus/input/devices"
}

# Step 2: Check USB keyboard detection
check_usb_keyboard() {
    log_step "Checking USB keyboard detection..."
    
    echo "=== USB Keyboards ==="
    USB_KEYBOARDS=$(lsusb | grep -i keyboard)
    if [ -n "$USB_KEYBOARDS" ]; then
        log_info "Found USB keyboards:"
        echo "$USB_KEYBOARDS"
        
        # Extract vendor and product IDs
        VENDOR_ID=$(echo "$USB_KEYBOARDS" | head -1 | sed 's/.*ID \([0-9a-f]*\):\([0-9a-f]*\).*/\1/')
        PRODUCT_ID=$(echo "$USB_KEYBOARDS" | head -1 | sed 's/.*ID \([0-9a-f]*\):\([0-9a-f]*\).*/\2/')
        log_info "First keyboard: VendorID=$VENDOR_ID, ProductID=$PRODUCT_ID"
    else
        log_error "No USB keyboards detected!"
        return 1
    fi
    
    echo ""
    echo "=== Input Event Devices ==="
    ls -la /dev/input/event* 2>/dev/null || log_warn "No input event devices"
}

# Step 3: Unload conflicting drivers
unload_builtin_drivers() {
    log_step "Unloading built-in keyboard drivers..."
    
    # First unload custom driver if loaded
    if lsmod | grep -q "^usbkbd "; then
        log_info "Unloading custom usbkbd driver first..."
        rmmod usbkbd 2>/dev/null || log_warn "Failed to unload usbkbd"
    fi
    
    # Unload built-in drivers in correct order
    log_info "Unloading hid_generic..."
    rmmod hid_generic 2>/dev/null || log_warn "hid_generic not loaded or in use"
    
    log_info "Unloading usbhid..."
    rmmod usbhid 2>/dev/null || log_warn "usbhid not loaded or in use"
    
    log_info "Unloading hid..."
    rmmod hid 2>/dev/null || log_warn "hid not loaded or in use"
    
    # Wait a moment
    sleep 2
    
    log_info "Built-in drivers unloaded"
}

# Step 4: Load custom driver
load_custom_driver() {
    log_step "Loading custom USB keyboard driver..."
    
    # Check if driver file exists
    if [ ! -f "usbkbd.ko" ]; then
        log_error "usbkbd.ko not found!"
        log_info "Build it first with: make clean && make"
        return 1
    fi
    
    # Load custom driver
    log_info "Loading custom usbkbd.ko..."
    if insmod usbkbd.ko; then
        log_info "Custom driver loaded successfully!"
        
        # Verify loading
        if lsmod | grep -q "^usbkbd "; then
            log_info "Driver verified in kernel:"
            lsmod | grep "^usbkbd "
        else
            log_error "Driver loaded but not found in lsmod"
            return 1
        fi
    else
        log_error "Failed to load custom driver"
        dmesg | tail -10
        return 1
    fi
}

# Step 5: Force driver binding
force_driver_binding() {
    log_step "Forcing driver binding to USB keyboard..."
    
    # Find USB keyboard devices
    USB_DEVICES=$(lsusb | grep -i keyboard | cut -d' ' -f6 | cut -d':' -f1-2)
    
    if [ -z "$USB_DEVICES" ]; then
        log_warn "No USB keyboards found for binding"
        return 1
    fi
    
    for device in $USB_DEVICES; do
        VENDOR_ID=$(echo $device | cut -d':' -f1)
        PRODUCT_ID=$(echo $device | cut -d':' -f2)
        
        log_info "Attempting to bind to device: $VENDOR_ID:$PRODUCT_ID"
        
        # Find device path in sysfs
        DEVICE_PATH=$(find /sys/bus/usb/devices -name "*$VENDOR_ID:$PRODUCT_ID*" 2>/dev/null | head -1)
        
        if [ -n "$DEVICE_PATH" ]; then
            log_info "Found device path: $DEVICE_PATH"
            
            # Try to unbind from current driver
            if [ -f "$DEVICE_PATH/driver/unbind" ]; then
                DEVICE_NAME=$(basename $DEVICE_PATH)
                echo "$DEVICE_NAME" > "$DEVICE_PATH/driver/unbind" 2>/dev/null || true
                log_info "Unbound from current driver"
            fi
            
            # Wait a moment
            sleep 1
            
            # Try to bind to our driver
            if [ -d "/sys/bus/usb/drivers/usbkbd" ]; then
                DEVICE_NAME=$(basename $DEVICE_PATH)
                echo "$DEVICE_NAME" > /sys/bus/usb/drivers/usbkbd/bind 2>/dev/null || {
                    log_warn "Failed to bind to custom driver"
                }
            fi
        fi
    done
}

# Step 6: Test driver functionality
test_driver_functionality() {
    log_step "Testing driver functionality..."
    
    # Check driver status
    if ! lsmod | grep -q "^usbkbd "; then
        log_error "Custom driver not loaded!"
        return 1
    fi
    
    log_info "Custom driver is loaded"
    
    # Monitor dmesg for driver messages
    log_info "Recent kernel messages:"
    dmesg | tail -20 | grep -E "(usbkbd|USB|keyboard)" || dmesg | tail -10
    
    echo ""
    log_info "Testing keyboard input detection..."
    echo "=== DRIVER TEST ==="
    echo "1. The driver should now intercept keyboard input"
    echo "2. Open another terminal and run: vi test.txt"
    echo "3. Try pressing 'A' key → Should output 'B'"
    echo "4. Try pressing 'B' key → Should output 'A'"
    echo "5. Other keys should work normally"
    echo ""
    echo "To monitor driver activity in real-time:"
    echo "   sudo dmesg -w | grep usbkbd"
    echo ""
    
    # Show current input devices
    echo "=== CURRENT INPUT DEVICES ==="
    cat /proc/bus/input/devices | grep -A 5 -B 2 -i "usbkbd\|keyboard" || {
        log_warn "Custom driver not found in input devices"
        log_info "This might indicate driver binding issues"
    }
}

# Step 7: Monitor driver activity
monitor_driver() {
    log_step "Monitoring driver activity..."
    
    echo "Monitoring kernel messages for 30 seconds..."
    echo "Please press some keys (A, B, other keys) now..."
    echo "Press Ctrl+C to stop monitoring early"
    
    timeout 30s dmesg -w | grep --line-buffered -E "(usbkbd|Unknown key|MODE|pressed)" || {
        log_warn "No driver activity detected"
        log_info "This suggests the driver is not receiving keyboard events"
    }
    
    echo ""
    log_info "Monitoring completed"
}

# Step 8: Troubleshooting info
show_troubleshooting() {
    log_step "Troubleshooting information..."
    
    echo "=============================================="
    echo "TROUBLESHOOTING GUIDE"
    echo "=============================================="
    
    echo ""
    echo "🔍 ISSUE 1: Driver loaded but no key swapping"
    echo "CAUSE: Built-in drivers still intercepting keys"
    echo "SOLUTION:"
    echo "  sudo rmmod hid_generic usbhid hid"
    echo "  sudo insmod usbkbd.ko"
    echo ""
    
    echo "🔍 ISSUE 2: Driver not binding to keyboard"
    echo "CAUSE: USB keyboard using different protocol"
    echo "SOLUTION:"
    echo "  Check driver compatibility in usbkbd.c:"
    echo "  - USB_INTERFACE_CLASS_HID"
    echo "  - USB_INTERFACE_SUBCLASS_BOOT"
    echo "  - USB_INTERFACE_PROTOCOL_KEYBOARD"
    echo ""
    
    echo "🔍 ISSUE 3: VMware virtual keyboard issues"
    echo "CAUSE: VMware may present keyboard differently"
    echo "SOLUTION:"
    echo "  1. Use physical USB keyboard"
    echo "  2. Or modify driver to handle VMware devices"
    echo ""
    
    echo "🔍 ISSUE 4: SELinux blocking driver"
    echo "CAUSE: SELinux security policy"
    echo "SOLUTION:"
    echo "  sudo setenforce 0  # Temporary"
    echo "  sudo setsebool -P module_request 1"
    echo ""
    
    echo "🔍 ISSUE 5: Driver compilation issues"
    echo "CAUSE: Kernel API changes"
    echo "SOLUTION:"
    echo "  Check dmesg for specific errors"
    echo "  Verify kernel headers match running kernel"
    echo ""
    
    echo "=============================================="
    echo "VERIFICATION COMMANDS:"
    echo "=============================================="
    echo "lsmod | grep usbkbd                    # Check if loaded"
    echo "dmesg | grep usbkbd                    # Check driver messages"  
    echo "cat /proc/bus/input/devices | grep -A5 usbkbd  # Check input binding"
    echo "lsusb | grep -i keyboard               # Check USB keyboards"
    echo "=============================================="
}

# Main menu
show_menu() {
    echo ""
    echo "=============================================="
    echo "KEYBOARD DRIVER FIX MENU"
    echo "=============================================="
    echo "1. Check current status"
    echo "2. Check USB keyboard detection"
    echo "3. Unload built-in drivers"
    echo "4. Load custom driver"
    echo "5. Force driver binding"
    echo "6. Test driver functionality"
    echo "7. Monitor driver activity"
    echo "8. Show troubleshooting guide"
    echo "9. Full fix sequence (recommended)"
    echo "0. Exit"
    echo "=============================================="
    read -p "Choose option [0-9]: " choice
}

# Full fix sequence
full_fix_sequence() {
    log_step "Running full keyboard driver fix sequence..."
    
    check_current_status
    echo ""
    check_usb_keyboard
    echo ""
    unload_builtin_drivers
    echo ""
    load_custom_driver
    echo ""
    force_driver_binding
    echo ""
    test_driver_functionality
    
    echo ""
    log_info "=============================================="
    log_info "FULL FIX SEQUENCE COMPLETED!"
    log_info "=============================================="
    log_info "Now test in another terminal:"
    log_info "  vi test.txt"
    log_info "  Press 'A' → Should show 'B'"
    log_info "  Press 'B' → Should show 'A'"
    log_info "=============================================="
}

# Main execution
main() {
    case "${1:-}" in
        "auto"|"--auto")
            full_fix_sequence
            exit 0
            ;;
        "status"|"--status")
            check_current_status
            exit 0
            ;;
        "test"|"--test")
            test_driver_functionality
            exit 0
            ;;
        "monitor"|"--monitor")
            monitor_driver
            exit 0
            ;;
        "help"|"--help"|"-h")
            echo "Usage: $0 [option]"
            echo "Options:"
            echo "  auto     - Run full fix sequence"
            echo "  status   - Check current status"
            echo "  test     - Test driver functionality"
            echo "  monitor  - Monitor driver activity"
            echo "  help     - Show this help"
            exit 0
            ;;
    esac
    
    # Interactive mode
    while true; do
        show_menu
        case $choice in
            1) check_current_status ;;
            2) check_usb_keyboard ;;
            3) unload_builtin_drivers ;;
            4) load_custom_driver ;;
            5) force_driver_binding ;;
            6) test_driver_functionality ;;
            7) monitor_driver ;;
            8) show_troubleshooting ;;
            9) full_fix_sequence ;;
            0) exit 0 ;;
            *) log_error "Invalid option" ;;
        esac
        echo ""
        read -p "Press Enter to continue..."
    done
}

main "$@" 