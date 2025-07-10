# 🚀 HƯỚNG DẪN CHI TIẾT: Build & Test USB Keyboard Driver

## 📋 Mục tiêu

- Build driver USB keyboard với tính năng swap A ↔ B
- Load driver thành công vào CentOS 9
- Test chức năng: bấm A ra B, bấm B ra A

---

## 🔧 BƯỚC 1: CHUẨN BỊ MÔI TRƯỜNG

### **A. Kiểm tra hệ thống**

```bash
# Kiểm tra OS version
cat /etc/redhat-release

# Kiểm tra kernel version
uname -r

# Kiểm tra architecture
uname -m
```

**Kết quả mong đợi:**

```
CentOS Stream release 9 (hoặc RHEL 9)
Kernel: 5.x.x hoặc 6.x.x
Architecture: x86_64
```

### **B. Cài đặt dependencies**

```bash
# Cập nhật hệ thống
sudo dnf update -y

# Cài đặt development tools
sudo dnf groupinstall -y "Development Tools"

# Cài đặt kernel headers
sudo dnf install -y kernel-devel-$(uname -r)

# Cài đặt tools bổ sung
sudo dnf install -y gcc make vim nano usbutils kbd dkms
```

### **C. Verify cài đặt**

```bash
# Kiểm tra GCC
gcc --version

# Kiểm tra Make
make --version

# Kiểm tra kernel headers
ls -la /lib/modules/$(uname -r)/build
```

---

## 🏗️ BƯỚC 2: BUILD DRIVER

### **A. Kiểm tra files trong thư mục**

```bash
# Xem tất cả files
ls -la

# Files cần thiết:
# ✅ usbkbd.c         - Driver source code
# ✅ Makefile         - Build configuration
# ✅ *.sh scripts     - Test scripts
```

### **B. Setup scripts**

```bash
# Chạy setup master để làm tất cả scripts executable
chmod +x setup_centos9.sh
./setup_centos9.sh
```

### **C. Build driver**

```bash
# Clean build cũ (nếu có)
make clean

# Build driver
make

# Kiểm tra kết quả
ls -la usbkbd.ko
```

**Kết quả mong đợi:**

```bash
usbkbd.ko được tạo ra với size khoảng 400-500KB
```

**Nếu build FAILED:**

```bash
# Kiểm tra lỗi chi tiết
make 2>&1 | tee build.log
cat build.log

# Fix thường gặp:
sudo dnf install -y kernel-devel-$(uname -r)
sudo dnf install -y elfutils-libelf-devel
```

---

## 🔌 BƯỚC 3: CHUẨN BỊ USB KEYBOARD

### **A. VMware Settings (nếu dùng VMware)**

1. **Tắt VM CentOS 9**
2. **VM Settings → Hardware → USB Controller**
   - ✅ Enable: **USB 3.1**
   - ✅ Check: **Show all USB input devices**
3. **OK → Khởi động VM**

### **B. Connect USB Keyboard**

1. **Cắm bàn phím USB vào máy thật**
2. **VMware: VM → Removable Devices → [Keyboard] → Connect**

### **C. Verify USB keyboard**

```bash
# Kiểm tra USB devices
lsusb | grep -i keyboard

# Kiểm tra input devices
ls -la /dev/input/event*

# Test USB keyboard hoạt động bình thường
# Gõ vài phím để đảm bảo keyboard hoạt động
```

---

## ⚡ BƯỚC 4: FIX DRIVER PRIORITY (QUAN TRỌNG!)

### **A. Chạy quick fix (Khuyến nghị)**

```bash
# Chạy script fix nhanh
chmod +x quick_fix_driver.sh
sudo ./quick_fix_driver.sh
```

### **B. Hoặc fix thủ công**

```bash
# Unload built-in drivers
sudo rmmod hid_generic 2>/dev/null || true
sudo rmmod usbhid 2>/dev/null || true
sudo rmmod usbkbd 2>/dev/null || true

# Load custom driver
sudo insmod usbkbd.ko

# Verify
lsmod | grep usbkbd
```

### **C. Kết quả mong đợi**

```bash
✅ Custom driver loaded!
usbkbd                16384  0

🎯 TEST NOW:
   vi test.txt
   Press 'A' → Should show 'B'
   Press 'B' → Should show 'A'
```

---

## 🧪 BƯỚC 5: TEST DRIVER

### **A. Test cơ bản**

**Terminal 1 - Monitor driver:**

```bash
# Monitor driver activity real-time
sudo dmesg -w | grep usbkbd
```

**Terminal 2 - Test keyboard:**

```bash
# Mở text editor
vi test.txt

# Test key swapping:
# - Bấm phím 'A' → Sẽ ra chữ 'B'
# - Bấm phím 'B' → Sẽ ra chữ 'A'
# - Các phím khác hoạt động bình thường

# Thoát vi: :q!
```

### **B. Test với different editors**

```bash
# Test với nano
nano test.txt

# Test với echo
echo "Test: AB ab AB"  # Sẽ ra: "Test: BA ba BA"

# Test với terminal typing
# Chỉ cần gõ trực tiếp trong terminal
```

### **C. Test LED functionality (nếu có)**

```bash
# Test NumLock LED
setleds +num    # Bật NumLock
setleds -num    # Tắt NumLock

# Test CapsLock LED
setleds +caps   # Bật CapsLock
setleds -caps   # Tắt CapsLock

# Monitor LED mode changes
sudo dmesg | grep -E "(MODE|led)"
```

---

## 📊 BƯỚC 6: VERIFICATION & MONITORING

### **A. Check driver status**

```bash
# Kiểm tra driver loaded
lsmod | grep usbkbd

# Kiểm tra input devices
cat /proc/bus/input/devices | grep -A5 usbkbd

# Xem driver info
modinfo usbkbd.ko
```

### **B. Monitor logs**

```bash
# Xem recent logs
sudo dmesg | grep usbkbd

# Monitor real-time
sudo dmesg -w | grep -E "(usbkbd|Unknown key|MODE)"

# System logs
sudo journalctl -f | grep usbkbd
```

### **C. Performance test**

```bash
# Test typing speed
# Gõ nhanh A và B để xem driver có lag không

# Monitor CPU usage
top | grep usbkbd
```

---

## 🔧 BƯỚC 7: TROUBLESHOOTING

### **A. Nếu driver không load**

```bash
# Check build errors
make clean && make 2>&1 | tee build.log

# Check kernel compatibility
modinfo usbkbd.ko | grep vermagic

# Try force loading
sudo insmod usbkbd.ko 2>&1 | tee load.log
dmesg | tail -20
```

### **B. Nếu keys không swap**

```bash
# Run diagnostic script
chmod +x fix_keyboard_driver.sh
sudo ./fix_keyboard_driver.sh auto

# Manual debug
lsmod | grep -E "(hid|usb)"
cat /proc/bus/input/devices | grep -A10 keyboard
```

### **C. Nếu USB keyboard không nhận**

```bash
# Run USB debug
chmod +x usb_debug_centos9.sh
./usb_debug_centos9.sh auto

# Quick USB fix
chmod +x vmware_usb_fix.sh
sudo ./vmware_usb_fix.sh
```

---

## ✅ BƯỚC 8: KẾT QUẢ MONG ĐỢI

### **A. Build thành công:**

```
CC [M]  /path/to/usbkbd.o
LD [M]  /path/to/usbkbd.ko
✓ Build successful: usbkbd.ko (450KB)
```

### **B. Load thành công:**

```
✅ Custom driver loaded!
usbkbd                16384  0
[  123.456] usbkbd: loading out-of-tree module taints kernel
[  123.789] usbkbd: USB HID Boot Protocol keyboard driver v1.0
```

### **C. Test thành công:**

```
Input: A → Output: B ✅
Input: B → Output: A ✅
Input: C → Output: C ✅
Other keys work normally ✅

LED test:
[  234.567] usbkbd: Now change to MODE 2
[  245.678] usbkbd: Now change to MODE 1
```

---

## 🎯 COMPLETE TESTING SEQUENCE

### **Chạy full automated test:**

```bash
# Option 1: Complete test suite
chmod +x centos9_build_test.sh
sudo ./centos9_build_test.sh auto

# Option 2: Quick test
chmod +x centos9_quick_test.sh
sudo ./centos9_quick_test.sh

# Option 3: Manual step-by-step
sudo ./quick_fix_driver.sh
vi test.txt  # Test A→B, B→A
```

---

## 🚨 EMERGENCY RECOVERY

### **Nếu keyboard bị stuck:**

```bash
# Unload custom driver
sudo rmmod usbkbd

# Reload built-in drivers
sudo modprobe usbhid
sudo modprobe hid_generic

# Restart input subsystem
sudo systemctl restart systemd-udevd
```

### **Nếu system không respond:**

```bash
# Use VMware console
VM → Send Ctrl+Alt+Del

# Or reboot VM
sudo reboot
```

---

## 📞 SUPPORT & DEBUG INFO

### **Collect debug info:**

```bash
# System info
uname -a
cat /etc/redhat-release
lsusb | grep -i keyboard
lsmod | grep -E "(usbkbd|hid|usb)"

# Driver info
ls -la usbkbd.ko
modinfo usbkbd.ko
dmesg | grep usbkbd

# Input devices
cat /proc/bus/input/devices | grep -A10 -B5 keyboard
ls -la /dev/input/event*
```

### **Share debug log:**

```bash
# Create comprehensive debug log
{
    echo "=== SYSTEM INFO ==="
    uname -a
    cat /etc/redhat-release

    echo -e "\n=== USB DEVICES ==="
    lsusb

    echo -e "\n=== LOADED MODULES ==="
    lsmod | grep -E "(usbkbd|hid|usb)"

    echo -e "\n=== DRIVER INFO ==="
    ls -la usbkbd.ko
    modinfo usbkbd.ko 2>/dev/null | head -10

    echo -e "\n=== KERNEL MESSAGES ==="
    dmesg | grep -E "(usbkbd|keyboard|hid)" | tail -20

    echo -e "\n=== INPUT DEVICES ==="
    cat /proc/bus/input/devices | grep -A5 -B2 keyboard

} > debug_report.txt

cat debug_report.txt
```

---

## 🎉 SUCCESS CHECKLIST

- ✅ CentOS 9 system ready
- ✅ Dependencies installed
- ✅ Driver builds successfully (usbkbd.ko created)
- ✅ USB keyboard detected by system
- ✅ Built-in drivers unloaded
- ✅ Custom driver loaded (lsmod shows usbkbd)
- ✅ Key swapping works: A→B, B→A
- ✅ Other keys work normally
- ✅ LED functionality tested
- ✅ No errors in dmesg

**🎯 Khi đạt được tất cả ✅ trên, driver đã hoạt động hoàn hảo!**
