#!/bin/bash

# Build and Test Script for USB Keyboard Driver
# For CentOS 6 with kernel 2.6.32

echo "=========================================="
echo "USB Keyboard Driver Build & Test Script"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. This is needed for loading/unloading modules."
    else
        print_error "This script needs to be run as root for module operations."
        echo "Run: sudo $0"
        exit 1
    fi
}

# Check if kernel headers are installed
check_kernel_headers() {
    print_status "Checking kernel headers..."
    if [ -d "/lib/modules/$(uname -r)/build" ]; then
        print_status "Kernel headers found: /lib/modules/$(uname -r)/build"
    else
        print_error "Kernel headers not found!"
        print_status "Install with: yum install kernel-devel-$(uname -r)"
        exit 1
    fi
}

# Check if build tools are installed
check_build_tools() {
    print_status "Checking build tools..."
    if ! command -v gcc &> /dev/null; then
        print_error "GCC not found!"
        print_status "Install with: yum install gcc"
        exit 1
    fi
    
    if ! command -v make &> /dev/null; then
        print_error "Make not found!"
        print_status "Install with: yum install make"
        exit 1
    fi
    
    print_status "Build tools OK"
}

# Clean previous build
clean_build() {
    print_status "Cleaning previous build..."
    make clean
    print_status "Clean completed"
}

# Build the driver
build_driver() {
    print_status "Building USB keyboard driver..."
    make
    
    if [ $? -eq 0 ]; then
        print_status "Build successful! usbkbd.ko created"
        ls -la usbkbd.ko
    else
        print_error "Build failed!"
        exit 1
    fi
}

# Load the driver
load_driver() {
    print_status "Loading driver..."
    
    # Unload if already loaded
    if lsmod | grep -q "usbkbd"; then
        print_warning "Driver already loaded, unloading first..."
        rmmod usbkbd 2>/dev/null
    fi
    
    # Load the driver
    insmod usbkbd.ko
    
    if [ $? -eq 0 ]; then
        print_status "Driver loaded successfully"
        lsmod | grep usbkbd
    else
        print_error "Failed to load driver"
        exit 1
    fi
    
    # Check dmesg for load messages
    print_status "Checking kernel messages..."
    dmesg | tail -10
}

# Test keyboard functionality
test_keyboard() {
    print_status "Testing keyboard functionality..."
    
    # Check if driver is loaded
    if ! lsmod | grep -q "usbkbd"; then
        print_error "Driver not loaded!"
        return 1
    fi
    
    # List USB devices
    print_status "Current USB devices:"
    lsusb | grep -i keyboard || lsusb
    
    # Check input devices
    print_status "Input devices:"
    ls -la /dev/input/event* | tail -5
    
    # Test key remapping (A <-> B swap)
    print_warning "Please test the following:"
    echo "1. Press 'A' key - should output 'B'"
    echo "2. Press 'B' key - should output 'A'"
    echo "3. Press other keys to ensure they work normally"
    echo ""
    print_status "Open a text editor and test for 10 seconds..."
    
    # Monitor dmesg for key events
    print_status "Monitoring kernel messages (press keys now)..."
    timeout 10s bash -c 'tail -f /var/log/messages | grep usbkbd' &
    sleep 10
    kill %1 2>/dev/null
    
    # Check recent dmesg
    print_status "Recent kernel messages:"
    dmesg | tail -20 | grep -E "(usbkbd|Unknown key|pressed)"
}

# Test LED functionality
test_leds() {
    print_status "Testing LED functionality..."
    
    # Test NumLock LED
    print_status "Testing NumLock LED..."
    setleds +num 2>/dev/null || echo "Could not control NumLock"
    sleep 1
    setleds -num 2>/dev/null || echo "Could not control NumLock"
    
    # Test CapsLock LED  
    print_status "Testing CapsLock LED..."
    setleds +caps 2>/dev/null || echo "Could not control CapsLock"
    sleep 1
    setleds -caps 2>/dev/null || echo "Could not control CapsLock"
    
    # Test ScrollLock LED
    print_status "Testing ScrollLock LED..."
    setleds +scroll 2>/dev/null || echo "Could not control ScrollLock"
    sleep 1
    setleds -scroll 2>/dev/null || echo "Could not control ScrollLock"
    
    print_status "LED test completed"
}

# Unload the driver
unload_driver() {
    print_status "Unloading driver..."
    
    if lsmod | grep -q "usbkbd"; then
        rmmod usbkbd
        if [ $? -eq 0 ]; then
            print_status "Driver unloaded successfully"
        else
            print_error "Failed to unload driver"
        fi
    else
        print_warning "Driver not loaded"
    fi
    
    # Check dmesg for unload messages
    print_status "Checking kernel messages after unload..."
    dmesg | tail -10
}

# Monitor system logs
monitor_logs() {
    print_status "Monitoring system logs for driver activity..."
    print_status "Press Ctrl+C to stop monitoring"
    
    tail -f /var/log/messages | grep --line-buffered usbkbd
}

# Show driver info
show_info() {
    print_status "Driver Information:"
    echo "Module file: $(ls -la usbkbd.ko 2>/dev/null || echo 'Not built')"
    echo "Kernel version: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo ""
    
    if lsmod | grep -q "usbkbd"; then
        print_status "Driver Status: LOADED"
        echo "Module info:"
        modinfo usbkbd.ko 2>/dev/null | head -10
    else
        print_status "Driver Status: NOT LOADED"
    fi
}

# Main menu
show_menu() {
    echo ""
    echo "=========================================="
    echo "USB Keyboard Driver Test Menu"
    echo "=========================================="
    echo "1. Check prerequisites"
    echo "2. Build driver"
    echo "3. Load driver"
    echo "4. Test keyboard (A<->B swap)"
    echo "5. Test LED functionality"
    echo "6. Unload driver"
    echo "7. Monitor logs"
    echo "8. Show driver info"
    echo "9. Full automated test"
    echo "0. Exit"
    echo "=========================================="
    read -p "Choose option [0-9]: " choice
}

# Full automated test
full_test() {
    print_status "Running full automated test..."
    
    check_kernel_headers
    check_build_tools
    clean_build
    build_driver
    load_driver
    show_info
    test_keyboard
    test_leds
    
    print_status "Full test completed!"
    print_status "Driver is loaded and ready for testing"
}

# Main execution
main() {
    if [ "$1" == "auto" ]; then
        check_root
        full_test
        exit 0
    fi
    
    while true; do
        show_menu
        case $choice in
            1)
                check_kernel_headers
                check_build_tools
                ;;
            2)
                clean_build
                build_driver
                ;;
            3)
                check_root
                load_driver
                ;;
            4)
                test_keyboard
                ;;
            5)
                test_leds
                ;;
            6)
                check_root
                unload_driver
                ;;
            7)
                monitor_logs
                ;;
            8)
                show_info
                ;;
            9)
                check_root
                full_test
                ;;
            0)
                print_status "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@" 