#!/bin/bash

# ============================================
# ALL-IN-ONE USB Keyboard Driver Test Script
# ============================================

set -e  # Exit on any error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_success() { echo -e "${PURPLE}[SUCCESS]${NC} $1"; }

# Banner
show_banner() {
    echo "=============================================="
    echo "USB KEYBOARD DRIVER - ONE-CLICK TEST SUITE"
    echo "=============================================="
    echo "Target: CentOS 9 / RHEL 9"
    echo "Feature: A ↔ B Key Swapping"
    echo "Date: $(date)"
    echo "=============================================="
    echo ""
}

# Check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script requires root privileges"
        echo "Usage: sudo $0"
        exit 1
    fi
    log_info "Running with root privileges ✓"
}

# Step 1: System check
system_check() {
    log_step "STEP 1: System environment check"
    
    # OS Check
    if grep -q "CentOS Stream release 9\|Red Hat Enterprise Linux release 9" /etc/redhat-release 2>/dev/null; then
        log_success "OS: $(cat /etc/redhat-release)"
    else
        log_warn "OS: $(cat /etc/redhat-release 2>/dev/null || echo 'Unknown')"
        log_warn "This script is optimized for CentOS 9, continuing anyway..."
    fi
    
    # Kernel check
    KERNEL_VERSION=$(uname -r)
    KERNEL_MAJOR=$(echo $KERNEL_VERSION | cut -d. -f1)
    log_info "Kernel: $KERNEL_VERSION"
    
    if [ "$KERNEL_MAJOR" -ge 5 ]; then
        log_success "Kernel version compatible ✓"
    else
        log_error "Kernel too old (need 5.x+), found: $KERNEL_VERSION"
        exit 1
    fi
    
    # Architecture check
    ARCH=$(uname -m)
    log_info "Architecture: $ARCH"
    
    if [ "$ARCH" = "x86_64" ]; then
        log_success "Architecture compatible ✓"
    else
        log_warn "Non-x86_64 architecture detected"
    fi
}

# Step 2: Install dependencies
install_dependencies() {
    log_step "STEP 2: Installing dependencies"
    
    log_info "Updating package database..."
    dnf makecache >/dev/null 2>&1
    
    log_info "Installing Development Tools..."
    dnf groupinstall -y "Development Tools" >/dev/null 2>&1 || {
        log_warn "Group install failed, trying individual packages..."
        dnf install -y gcc make >/dev/null 2>&1
    }
    
    log_info "Installing kernel development headers..."
    dnf install -y kernel-devel-${KERNEL_VERSION} >/dev/null 2>&1 || {
        log_warn "Exact kernel headers not found, installing latest..."
        dnf install -y kernel-devel >/dev/null 2>&1
    }
    
    log_info "Installing additional tools..."
    dnf install -y usbutils kbd vim nano elfutils-libelf-devel >/dev/null 2>&1 || {
        log_warn "Some additional packages failed to install"
    }
    
    log_success "Dependencies installed ✓"
}

# Step 3: Verify build environment
verify_environment() {
    log_step "STEP 3: Verifying build environment"
    
    # Check GCC
    if command -v gcc >/dev/null 2>&1; then
        GCC_VERSION=$(gcc --version | head -1)
        log_success "GCC: $GCC_VERSION ✓"
    else
        log_error "GCC not found!"
        exit 1
    fi
    
    # Check Make
    if command -v make >/dev/null 2>&1; then
        MAKE_VERSION=$(make --version | head -1)
        log_success "Make: $MAKE_VERSION ✓"
    else
        log_error "Make not found!"
        exit 1
    fi
    
    # Check kernel headers
    KERNEL_BUILD_DIR="/lib/modules/${KERNEL_VERSION}/build"
    if [ -d "$KERNEL_BUILD_DIR" ]; then
        log_success "Kernel headers: $KERNEL_BUILD_DIR ✓"
    else
        log_error "Kernel headers not found at: $KERNEL_BUILD_DIR"
        exit 1
    fi
    
    # Check source files
    if [ -f "usbkbd.c" ] && [ -f "Makefile" ]; then
        log_success "Source files present ✓"
    else
        log_error "Missing source files (usbkbd.c or Makefile)"
        exit 1
    fi
}

# Step 4: Build driver
build_driver() {
    log_step "STEP 4: Building USB keyboard driver"
    
    # Clean previous build
    log_info "Cleaning previous build..."
    make clean >/dev/null 2>&1 || true
    
    # Build driver
    log_info "Compiling driver..."
    if make 2>&1 | tee build.log >/dev/null; then
        if [ -f "usbkbd.ko" ]; then
            FILE_SIZE=$(ls -lh usbkbd.ko | awk '{print $5}')
            log_success "Driver built successfully: usbkbd.ko ($FILE_SIZE) ✓"
        else
            log_error "Build reported success but usbkbd.ko not found"
            exit 1
        fi
    else
        log_error "Build failed!"
        echo "Build log:"
        cat build.log | tail -20
        exit 1
    fi
}

# Step 5: Check USB devices
check_usb_devices() {
    log_step "STEP 5: Checking USB devices"
    
    log_info "Installing USB utilities if needed..."
    command -v lsusb >/dev/null 2>&1 || dnf install -y usbutils >/dev/null 2>&1
    
    log_info "Scanning USB devices..."
    USB_DEVICES=$(lsusb 2>/dev/null | wc -l)
    log_info "Found $USB_DEVICES USB devices"
    
    USB_KEYBOARDS=$(lsusb 2>/dev/null | grep -i keyboard | wc -l)
    if [ "$USB_KEYBOARDS" -gt 0 ]; then
        log_success "Found $USB_KEYBOARDS USB keyboard(s) ✓"
        lsusb | grep -i keyboard | while read line; do
            log_info "  → $line"
        done
    else
        log_warn "No USB keyboards detected"
        log_info "This might be VMware virtual keyboard or PS/2"
        log_info "Driver will still work if USB keyboard is connected later"
    fi
    
    log_info "Input devices:"
    INPUT_DEVICES=$(ls /dev/input/event* 2>/dev/null | wc -l)
    log_info "Found $INPUT_DEVICES input event devices"
}

# Step 6: Load driver
load_driver() {
    log_step "STEP 6: Loading custom USB keyboard driver"
    
    # Unload conflicting drivers
    log_info "Unloading conflicting built-in drivers..."
    rmmod usbkbd 2>/dev/null || true
    rmmod hid_generic 2>/dev/null || true
    rmmod usbhid 2>/dev/null || true
    
    # Small delay
    sleep 2
    
    # Load custom driver
    log_info "Loading custom usbkbd driver..."
    if insmod usbkbd.ko 2>&1; then
        log_success "Custom driver loaded ✓"
        
        # Verify loading
        if lsmod | grep -q "^usbkbd "; then
            DRIVER_INFO=$(lsmod | grep "^usbkbd ")
            log_success "Driver verified in kernel: $DRIVER_INFO ✓"
        else
            log_error "Driver loaded but not found in lsmod"
            exit 1
        fi
        
    else
        log_error "Failed to load custom driver"
        log_info "Checking dmesg for errors..."
        dmesg | tail -10
        exit 1
    fi
}

# Step 7: Test driver functionality
test_driver() {
    log_step "STEP 7: Testing driver functionality"
    
    # Check driver status
    if ! lsmod | grep -q "^usbkbd "; then
        log_error "Driver not loaded!"
        exit 1
    fi
    
    log_info "Checking kernel messages..."
    RECENT_LOGS=$(dmesg | grep usbkbd | tail -5)
    if [ -n "$RECENT_LOGS" ]; then
        log_success "Driver logs found ✓"
        echo "$RECENT_LOGS" | while read line; do
            log_info "  → $line"
        done
    else
        log_warn "No driver logs found in dmesg"
    fi
    
    # Check input devices
    log_info "Checking input device registration..."
    if cat /proc/bus/input/devices | grep -q "usbkbd"; then
        log_success "Driver registered as input device ✓"
    else
        log_warn "Driver not found in input devices"
        log_info "This might indicate binding issues"
    fi
    
    log_success "Driver functionality check completed ✓"
}

# Step 8: Interactive test
interactive_test() {
    log_step "STEP 8: Interactive keyboard test"
    
    echo ""
    echo "=============================================="
    echo "🎯 INTERACTIVE KEYBOARD TEST"
    echo "=============================================="
    echo ""
    echo "Driver is now loaded and ready for testing!"
    echo ""
    echo "📋 TEST INSTRUCTIONS:"
    echo "1. Open another terminal window"
    echo "2. Run: vi test.txt (or nano test.txt)"
    echo "3. Try typing:"
    echo "   • Press 'A' key → Should output 'B'"
    echo "   • Press 'B' key → Should output 'A'"
    echo "   • Other keys should work normally"
    echo ""
    echo "📊 MONITORING:"
    echo "You can monitor driver activity with:"
    echo "   sudo dmesg -w | grep usbkbd"
    echo ""
    echo "🔧 LED TEST (if available):"
    echo "   setleds +num     # Turn on NumLock"
    echo "   setleds -num     # Turn off NumLock"
    echo "   setleds +caps    # Turn on CapsLock"
    echo "   setleds -caps    # Turn off CapsLock"
    echo ""
    echo "🚨 TO UNLOAD DRIVER:"
    echo "   sudo rmmod usbkbd"
    echo ""
    echo "=============================================="
    
    # Ask user if they want to test now
    echo ""
    read -p "Do you want to start a monitoring session now? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Starting driver monitoring..."
        echo "Press Ctrl+C to stop monitoring"
        echo "Now test the keyboard in another terminal..."
        echo ""
        
        # Monitor for 60 seconds or until Ctrl+C
        timeout 60s dmesg -w | grep --line-buffered -E "(usbkbd|Unknown key|MODE)" || {
            echo ""
            log_info "Monitoring stopped"
        }
    fi
}

# Step 9: Generate report
generate_report() {
    log_step "STEP 9: Generating test report"
    
    REPORT_FILE="driver_test_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "USB KEYBOARD DRIVER TEST REPORT"
        echo "=========================================="
        echo "Generated: $(date)"
        echo "Script: run_everything.sh"
        echo ""
        
        echo "=== SYSTEM INFORMATION ==="
        echo "OS: $(cat /etc/redhat-release 2>/dev/null || echo 'Unknown')"
        echo "Kernel: $(uname -r)"
        echo "Architecture: $(uname -m)"
        echo "Hostname: $(hostname)"
        echo ""
        
        echo "=== BUILD STATUS ==="
        if [ -f "usbkbd.ko" ]; then
            echo "Status: SUCCESS"
            echo "File: $(ls -lh usbkbd.ko)"
            echo ""
            echo "Module Info:"
            modinfo usbkbd.ko 2>/dev/null | head -10 || echo "modinfo failed"
        else
            echo "Status: FAILED - usbkbd.ko not found"
        fi
        echo ""
        
        echo "=== DRIVER STATUS ==="
        if lsmod | grep -q "^usbkbd "; then
            echo "Status: LOADED"
            lsmod | grep "^usbkbd "
        else
            echo "Status: NOT LOADED"
        fi
        echo ""
        
        echo "=== USB DEVICES ==="
        lsusb 2>/dev/null | grep -i keyboard || echo "No USB keyboards found"
        echo ""
        
        echo "=== INPUT DEVICES ==="
        ls -la /dev/input/event* 2>/dev/null | tail -3 || echo "No input devices"
        echo ""
        
        echo "=== KERNEL MESSAGES ==="
        dmesg | grep usbkbd | tail -10 || echo "No driver messages"
        echo ""
        
        echo "=== TEST COMPLETION ==="
        echo "Report generated: $(date)"
        echo "Next steps: Test keyboard A→B, B→A swapping"
        echo "Monitor: sudo dmesg -w | grep usbkbd"
        echo "Unload: sudo rmmod usbkbd"
        
    } > "$REPORT_FILE"
    
    log_success "Test report saved: $REPORT_FILE ✓"
}

# Main execution
main() {
    show_banner
    
    # Handle command line arguments
    case "${1:-}" in
        "--help"|"-h")
            echo "Usage: sudo $0 [options]"
            echo ""
            echo "Options:"
            echo "  --help, -h     Show this help"
            echo "  --skip-deps    Skip dependency installation"
            echo "  --build-only   Only build the driver"
            echo "  --test-only    Only test (assume driver exists)"
            echo ""
            echo "Default: Run complete sequence"
            exit 0
            ;;
        "--skip-deps")
            SKIP_DEPS=1
            ;;
        "--build-only")
            BUILD_ONLY=1
            ;;
        "--test-only")
            TEST_ONLY=1
            ;;
    esac
    
    # Run sequence based on flags
    if [ -z "$TEST_ONLY" ]; then
        check_root
        system_check
        
        if [ -z "$SKIP_DEPS" ]; then
            install_dependencies
        fi
        
        verify_environment
        build_driver
        
        if [ -n "$BUILD_ONLY" ]; then
            log_success "Build completed successfully!"
            log_info "Next: sudo $0 --test-only"
            exit 0
        fi
    fi
    
    if [ -z "$BUILD_ONLY" ]; then
        check_root
        check_usb_devices
        load_driver
        test_driver
        interactive_test
        generate_report
    fi
    
    echo ""
    log_success "=============================================="
    log_success "🎉 ALL STEPS COMPLETED SUCCESSFULLY!"
    log_success "=============================================="
    log_success "Driver is loaded and ready for testing"
    log_success "Test: Press A→B, B→A in text editor"
    log_success "Monitor: sudo dmesg -w | grep usbkbd"
    log_success "Unload: sudo rmmod usbkbd"
    log_success "=============================================="
}

# Script entry point
main "$@" 