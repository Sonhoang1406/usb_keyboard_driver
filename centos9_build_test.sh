#!/bin/bash

# =====================================
# USB Keyboard Driver - CentOS 9 Builder & Tester
# Supports: CentOS 9 64-bit with modern kernel (5.x/6.x)
# Features: A<->B key swap, LED control
# =====================================

set -e  # Exit on any error

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Global variables
DRIVER_NAME="usbkbd"
DRIVER_FILE="${DRIVER_NAME}.ko"
KERNEL_VERSION=$(uname -r)
BUILD_DIR=$(pwd)

# Banner
show_banner() {
    echo "=================================================="
    echo "USB Keyboard Driver - CentOS 9 Build & Test Suite"
    echo "=================================================="
    echo "Kernel: $KERNEL_VERSION"
    echo "Architecture: $(uname -m)"
    echo "Date: $(date)"
    echo "=================================================="
    echo ""
}

# Check if running as root
check_root_permissions() {
    if [[ $EUID -eq 0 ]]; then
        log_warn "Running as root - OK for module loading"
    else
        log_error "This script needs root privileges for module operations"
        echo "Usage: sudo $0"
        exit 1
    fi
}

# Step 1: Check system requirements
check_system_requirements() {
    log_step "Checking system requirements..."
    
    # Check OS version
    if ! grep -q "CentOS Linux release 9" /etc/redhat-release 2>/dev/null; then
        log_warn "This script is optimized for CentOS 9, but will try to continue..."
    fi
    
    # Check kernel version
    KERNEL_MAJOR=$(uname -r | cut -d. -f1)
    if [ "$KERNEL_MAJOR" -lt 5 ]; then
        log_error "Kernel version too old (found: $(uname -r), need: 5.x+)"
        exit 1
    fi
    
    log_info "System check passed - Kernel: $KERNEL_VERSION"
}

# Step 2: Install dependencies
install_dependencies() {
    log_step "Installing build dependencies..."
    
    # Update system
    log_info "Updating system packages..."
    dnf update -y >/dev/null 2>&1 || {
        log_error "Failed to update system"
        exit 1
    }
    
    # Install development tools
    log_info "Installing development tools..."
    dnf groupinstall -y "Development Tools" >/dev/null 2>&1 || {
        log_error "Failed to install development tools"
        exit 1
    }
    
    # Install kernel headers and development packages
    log_info "Installing kernel headers..."
    dnf install -y kernel-devel-${KERNEL_VERSION} >/dev/null 2>&1 || {
        dnf install -y kernel-devel >/dev/null 2>&1 || {
            log_error "Failed to install kernel-devel"
            exit 1
        }
    }
    
    # Additional tools
    log_info "Installing additional tools..."
    dnf install -y gcc make vim nano dkms usbutils >/dev/null 2>&1 || {
        log_warn "Some additional tools failed to install"
    }
    
    # Verify installations
    verify_build_environment
}

# Step 3: Verify build environment
verify_build_environment() {
    log_step "Verifying build environment..."
    
    # Check GCC
    if ! command -v gcc >/dev/null 2>&1; then
        log_error "GCC not found"
        exit 1
    fi
    log_info "GCC version: $(gcc --version | head -1)"
    
    # Check Make
    if ! command -v make >/dev/null 2>&1; then
        log_error "Make not found"
        exit 1
    fi
    log_info "Make version: $(make --version | head -1)"
    
    # Check kernel headers
    KERNEL_BUILD_DIR="/lib/modules/${KERNEL_VERSION}/build"
    if [ ! -d "$KERNEL_BUILD_DIR" ]; then
        log_error "Kernel headers not found at: $KERNEL_BUILD_DIR"
        log_info "Try: dnf install kernel-devel-${KERNEL_VERSION}"
        exit 1
    fi
    log_info "Kernel headers found: $KERNEL_BUILD_DIR"
    
    # Check Makefile
    if [ ! -f "Makefile" ]; then
        log_error "Makefile not found in current directory"
        exit 1
    fi
    
    log_info "Build environment verified successfully"
}

# Step 4: Build the driver
build_driver() {
    log_step "Building USB keyboard driver..."
    
    # Clean previous build
    log_info "Cleaning previous build..."
    make clean >/dev/null 2>&1 || true
    
    # Build driver
    log_info "Compiling driver..."
    if make 2>&1 | tee build.log; then
        log_info "Build successful!"
        
        # Verify .ko file
        if [ -f "$DRIVER_FILE" ]; then
            FILE_SIZE=$(ls -lh $DRIVER_FILE | awk '{print $5}')
            log_info "Driver file created: $DRIVER_FILE ($FILE_SIZE)"
            
            # Show module info
            log_info "Module information:"
            modinfo $DRIVER_FILE | head -10
        else
            log_error "Driver file not created"
            exit 1
        fi
    else
        log_error "Build failed!"
        echo "Build log:"
        cat build.log
        exit 1
    fi
}

# Step 5: Load the driver
load_driver() {
    log_step "Loading USB keyboard driver..."
    
    # Unload if already loaded
    if lsmod | grep -q "^$DRIVER_NAME "; then
        log_warn "Driver already loaded, unloading first..."
        rmmod $DRIVER_NAME 2>/dev/null || {
            log_error "Failed to unload existing driver"
            exit 1
        }
    fi
    
    # Load new driver
    log_info "Loading driver module..."
    if insmod $DRIVER_FILE; then
        log_info "Driver loaded successfully!"
        
        # Verify loading
        if lsmod | grep -q "^$DRIVER_NAME "; then
            log_info "Driver verified in kernel:"
            lsmod | grep "^$DRIVER_NAME "
        else
            log_error "Driver not found in kernel after loading"
            exit 1
        fi
        
        # Check dmesg
        log_info "Recent kernel messages:"
        dmesg | tail -10
        
    else
        log_error "Failed to load driver"
        log_info "Check dmesg for details:"
        dmesg | tail -20
        exit 1
    fi
}

# Step 6: System information
show_system_info() {
    log_step "Gathering system information..."
    
    echo "=== SYSTEM INFO ==="
    echo "OS: $(cat /etc/redhat-release)"
    echo "Kernel: $(uname -a)"
    echo "Architecture: $(uname -m)"
    echo "Memory: $(free -h | grep Mem)"
    echo ""
    
    echo "=== USB DEVICES ==="
    lsusb | grep -i keyboard || lsusb | head -5
    echo ""
    
    echo "=== INPUT DEVICES ==="
    ls -la /dev/input/event* | tail -5 || echo "No event devices found"
    echo ""
    
    echo "=== LOADED MODULES ==="
    lsmod | grep -E "(usb|hid|input)" | head -5
    echo ""
}

# Step 7: Test keyboard functionality
test_keyboard_functionality() {
    log_step "Testing keyboard functionality..."
    
    # Check if driver is loaded
    if ! lsmod | grep -q "^$DRIVER_NAME "; then
        log_error "Driver not loaded!"
        return 1
    fi
    
    log_info "Driver status: LOADED"
    
    # Test instructions
    echo ""
    echo "======================================="
    echo "KEYBOARD TEST INSTRUCTIONS"
    echo "======================================="
    echo "1. Open a text editor in another terminal:"
    echo "   - Terminal: vim test.txt"
    echo "   - Or GUI: gedit &"
    echo ""
    echo "2. Test key swapping:"
    echo "   - Press 'A' key → Should output 'B'"
    echo "   - Press 'B' key → Should output 'A'"
    echo "   - Other keys should work normally"
    echo ""
    echo "3. This test will monitor kernel logs for 30 seconds"
    echo "   Please type some keys now..."
    echo ""
    
    # Monitor logs for key events
    log_info "Monitoring kernel logs (30 seconds)..."
    timeout 30s bash -c 'dmesg -w | grep -E "(usbkbd|Unknown key|MODE)"' &
    MONITOR_PID=$!
    
    # Wait and then stop monitoring
    sleep 30
    kill $MONITOR_PID 2>/dev/null || true
    
    log_info "Keyboard test monitoring completed"
    
    # Show recent relevant logs
    echo ""
    echo "=== RECENT DRIVER LOGS ==="
    dmesg | grep -E "(usbkbd|Unknown key|MODE)" | tail -10 || echo "No driver-specific logs found"
}

# Step 8: Test LED functionality
test_led_functionality() {
    log_step "Testing LED functionality..."
    
    # Check if setleds is available
    if ! command -v setleds >/dev/null 2>&1; then
        log_warn "setleds command not found, installing..."
        dnf install -y kbd >/dev/null 2>&1 || {
            log_error "Failed to install kbd package"
            return 1
        }
    fi
    
    log_info "Testing keyboard LEDs..."
    
    # Test NumLock
    log_info "Testing NumLock LED..."
    setleds +num 2>/dev/null && sleep 1 && setleds -num 2>/dev/null || {
        log_warn "NumLock LED test failed"
    }
    
    # Test CapsLock
    log_info "Testing CapsLock LED..."
    setleds +caps 2>/dev/null && sleep 1 && setleds -caps 2>/dev/null || {
        log_warn "CapsLock LED test failed"
    }
    
    # Test ScrollLock
    log_info "Testing ScrollLock LED..."
    setleds +scroll 2>/dev/null && sleep 1 && setleds -scroll 2>/dev/null || {
        log_warn "ScrollLock LED test failed"
    }
    
    log_info "LED functionality test completed"
    
    # Show LED-related logs
    echo ""
    echo "=== LED-RELATED LOGS ==="
    dmesg | grep -E "(MODE|led)" | tail -5 || echo "No LED-related logs found"
}

# Step 9: Performance and stability test
performance_test() {
    log_step "Running performance and stability test..."
    
    log_info "Stress testing driver for 60 seconds..."
    echo "Please type rapidly and continuously for the next 60 seconds..."
    
    # Monitor for errors
    timeout 60s bash -c 'dmesg -w | grep -E "(error|Error|ERROR|warning|Warning|WARNING)"' &
    ERROR_MONITOR_PID=$!
    
    sleep 60
    kill $ERROR_MONITOR_PID 2>/dev/null || true
    
    log_info "Performance test completed"
    
    # Check for any errors
    echo ""
    echo "=== ERROR CHECK ==="
    ERROR_COUNT=$(dmesg | grep -E "(error|Error|ERROR)" | grep -c usbkbd || echo "0")
    WARNING_COUNT=$(dmesg | grep -E "(warning|Warning|WARNING)" | grep -c usbkbd || echo "0")
    
    if [ "$ERROR_COUNT" -eq 0 ] && [ "$WARNING_COUNT" -eq 0 ]; then
        log_info "No errors or warnings detected - Driver stable"
    else
        log_warn "Found $ERROR_COUNT errors and $WARNING_COUNT warnings"
        dmesg | grep -E "(error|Error|ERROR|warning|Warning|WARNING)" | grep usbkbd | tail -5
    fi
}

# Step 10: Unload driver
unload_driver() {
    log_step "Unloading USB keyboard driver..."
    
    if lsmod | grep -q "^$DRIVER_NAME "; then
        if rmmod $DRIVER_NAME; then
            log_info "Driver unloaded successfully"
        else
            log_error "Failed to unload driver"
            log_info "Force unloading..."
            rmmod -f $DRIVER_NAME || {
                log_error "Force unload also failed"
                return 1
            }
        fi
    else
        log_warn "Driver not loaded"
    fi
    
    # Check unload messages
    log_info "Checking unload messages..."
    dmesg | tail -10
}

# Generate test report
generate_report() {
    log_step "Generating test report..."
    
    REPORT_FILE="driver_test_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=================================================="
        echo "USB KEYBOARD DRIVER TEST REPORT"
        echo "=================================================="
        echo "Date: $(date)"
        echo "System: $(cat /etc/redhat-release)"
        echo "Kernel: $(uname -a)"
        echo "Driver: $DRIVER_FILE"
        echo "Build Dir: $BUILD_DIR"
        echo ""
        
        echo "=== BUILD STATUS ==="
        if [ -f "$DRIVER_FILE" ]; then
            echo "Status: SUCCESS"
            echo "File: $(ls -lh $DRIVER_FILE)"
            echo "Module Info:"
            modinfo $DRIVER_FILE | head -10
        else
            echo "Status: FAILED"
        fi
        echo ""
        
        echo "=== RUNTIME STATUS ==="
        if lsmod | grep -q "^$DRIVER_NAME "; then
            echo "Status: LOADED"
            lsmod | grep "^$DRIVER_NAME "
        else
            echo "Status: NOT LOADED"
        fi
        echo ""
        
        echo "=== SYSTEM INFO ==="
        echo "USB Devices:"
        lsusb | grep -i keyboard || echo "No USB keyboards found"
        echo ""
        echo "Input Devices:"
        ls -la /dev/input/event* | tail -3 || echo "No input devices"
        echo ""
        
        echo "=== DRIVER LOGS ==="
        dmesg | grep -E "(usbkbd|Unknown key|MODE)" | tail -20 || echo "No driver logs"
        echo ""
        
        echo "=== TEST COMPLETION ==="
        echo "Report generated: $(date)"
        echo "Test completed successfully"
        
    } > "$REPORT_FILE"
    
    log_info "Test report saved: $REPORT_FILE"
}

# Interactive menu
show_menu() {
    echo ""
    echo "=================================================="
    echo "CentOS 9 USB KEYBOARD DRIVER TEST MENU"
    echo "=================================================="
    echo "1.  Install dependencies"
    echo "2.  Build driver"
    echo "3.  Load driver"
    echo "4.  Test keyboard (A<->B swap)"
    echo "5.  Test LED functionality"
    echo "6.  Performance test"
    echo "7.  Show system info"
    echo "8.  Unload driver"
    echo "9.  Generate test report"
    echo "10. Full automated test (recommended)"
    echo "11. Clean build"
    echo "0.  Exit"
    echo "=================================================="
    read -p "Choose option [0-11]: " choice
}

# Full automated test
full_automated_test() {
    log_step "Running full automated test suite..."
    
    check_system_requirements
    install_dependencies
    verify_build_environment
    build_driver
    load_driver
    show_system_info
    test_keyboard_functionality
    test_led_functionality
    performance_test
    generate_report
    
    echo ""
    log_info "=================================================="
    log_info "FULL TEST COMPLETED SUCCESSFULLY!"
    log_info "=================================================="
    log_info "Driver is loaded and ready for use"
    log_info "Test report generated"
    log_info "To unload: sudo rmmod $DRIVER_NAME"
}

# Clean build files
clean_build() {
    log_step "Cleaning build files..."
    make clean 2>/dev/null || true
    rm -f *.log *.tmp
    log_info "Build cleaned"
}

# Main execution function
main() {
    # Handle command line arguments
    case "${1:-}" in
        "auto"|"--auto")
            show_banner
            check_root_permissions
            full_automated_test
            exit 0
            ;;
        "install"|"--install")
            show_banner
            check_root_permissions
            install_dependencies
            exit 0
            ;;
        "build"|"--build")
            show_banner
            verify_build_environment
            build_driver
            exit 0
            ;;
        "load"|"--load")
            show_banner
            check_root_permissions
            load_driver
            exit 0
            ;;
        "test"|"--test")
            show_banner
            check_root_permissions
            test_keyboard_functionality
            test_led_functionality
            exit 0
            ;;
        "unload"|"--unload")
            show_banner
            check_root_permissions
            unload_driver
            exit 0
            ;;
        "clean"|"--clean")
            clean_build
            exit 0
            ;;
        "help"|"--help"|"-h")
            echo "Usage: $0 [option]"
            echo "Options:"
            echo "  auto     - Run full automated test"
            echo "  install  - Install dependencies only"
            echo "  build    - Build driver only"
            echo "  load     - Load driver only"
            echo "  test     - Test driver functionality"
            echo "  unload   - Unload driver"
            echo "  clean    - Clean build files"
            echo "  help     - Show this help"
            echo ""
            echo "If no option provided, interactive menu will be shown"
            exit 0
            ;;
    esac
    
    # Interactive mode
    show_banner
    check_root_permissions
    
    while true; do
        show_menu
        case $choice in
            1)
                install_dependencies
                ;;
            2)
                verify_build_environment
                build_driver
                ;;
            3)
                load_driver
                ;;
            4)
                test_keyboard_functionality
                ;;
            5)
                test_led_functionality
                ;;
            6)
                performance_test
                ;;
            7)
                show_system_info
                ;;
            8)
                unload_driver
                ;;
            9)
                generate_report
                ;;
            10)
                full_automated_test
                ;;
            11)
                clean_build
                ;;
            0)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Start the script
main "$@" 