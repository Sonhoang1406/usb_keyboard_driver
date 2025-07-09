# USB Keyboard Driver - Build & Test Guide

## Mô tả

Driver USB keyboard có tính năng đặc biệt:

- **Swap phím A ↔ B**: Khi bấm phím A sẽ ra B, bấm phím B sẽ ra A
- **Điều khiển LED**: Hỗ trợ điều khiển NumLock, CapsLock, ScrollLock LED
- **Tương thích CentOS 6**: Đã được sửa đổi để tương thích với kernel 2.6.32

## Yêu cầu hệ thống

- **OS**: CentOS 6 (32-bit/64-bit)
- **Kernel**: 2.6.32 (đã test)
- **Tools**: gcc, make, kernel-devel

## Cài đặt dependencies

```bash
# Cài đặt các gói cần thiết
sudo yum install gcc make
sudo yum install kernel-devel-$(uname -r)

# Kiểm tra kernel headers
ls -la /lib/modules/$(uname -r)/build
```

## Cách 1: Test nhanh (Khuyến nghị)

```bash
# Làm cho script executable
chmod +x quick_test.sh

# Chạy test nhanh
./quick_test.sh
```

## Cách 2: Test đầy đủ với menu

```bash
# Làm cho script executable
chmod +x build_and_test.sh

# Chạy script với menu
sudo ./build_and_test.sh

# Hoặc chạy test tự động
sudo ./build_and_test.sh auto
```

## Cách 3: Thủ công từng bước

### Bước 1: Build driver

```bash
# Clean build cũ
make clean

# Build driver mới
make

# Kiểm tra file .ko được tạo
ls -la usbkbd.ko
```

### Bước 2: Load driver

```bash
# Load driver vào kernel
sudo insmod usbkbd.ko

# Kiểm tra driver đã được load
lsmod | grep usbkbd

# Xem thông báo kernel
sudo dmesg | tail -10
```

### Bước 3: Test chức năng

#### Test swap phím A ↔ B:

1. Mở text editor: `vi test.txt` hoặc `nano test.txt`
2. Bấm phím **A** → Kết quả: **B**
3. Bấm phím **B** → Kết quả: **A**
4. Các phím khác hoạt động bình thường

#### Test LED:

```bash
# Test bằng setleds
setleds +num      # Bật NumLock
setleds -num      # Tắt NumLock
setleds +caps     # Bật CapsLock
setleds -caps     # Tắt CapsLock
setleds +scroll   # Bật ScrollLock
setleds -scroll   # Tắt ScrollLock
```

### Bước 4: Monitor logs

```bash
# Xem log real-time
sudo tail -f /var/log/messages | grep usbkbd

# Xem dmesg
sudo dmesg | grep usbkbd

# Monitor key events
sudo dmesg -w    # Rồi bấm các phím để xem
```

### Bước 5: Unload driver

```bash
# Gỡ bỏ driver
sudo rmmod usbkbd

# Kiểm tra đã gỡ bỏ
lsmod | grep usbkbd

# Xem log sau khi gỡ bỏ
sudo dmesg | tail -10
```

## Troubleshooting

### Lỗi build

```bash
# Nếu thiếu kernel headers
sudo yum install kernel-devel-$(uname -r)

# Nếu thiếu gcc
sudo yum install gcc make

# Nếu lỗi permission
sudo chown -R $USER:$USER .
```

### Lỗi load driver

```bash
# Kiểm tra file .ko
file usbkbd.ko

# Kiểm tra kernel compatibility
modinfo usbkbd.ko

# Force unload nếu bị stuck
sudo rmmod -f usbkbd
```

### Driver không hoạt động

```bash
# Kiểm tra USB devices
lsusb | grep -i keyboard

# Kiểm tra input devices
ls -la /dev/input/event*

# Xem chi tiết log
sudo dmesg | grep -E "(usb|hid|keyboard|usbkbd)"
```

## Các script có sẵn

- **quick_test.sh**: Test nhanh, đơn giản
- **build_and_test.sh**: Test đầy đủ với menu
- **load.sh**: Load driver + xem log
- **unload.sh**: Unload driver + xem log
- **testLed.sh**: Test chức năng LED
- **testphim.sh**: Test chức năng phím
- **testXulyngat.sh**: Test xử lý ngắt
- **testGoNap.sh**: Test load/unload

## Kết quả mong đợi

### Build thành công:

```
✓ Build successful!
usbkbd.ko created (khoảng 400KB+)
```

### Load thành công:

```
✓ Driver loaded successfully!
usbkbd                  16384  0
```

### Test phím thành công:

- Bấm **A** → Ra **B**
- Bấm **B** → Ra **A**
- Các phím khác bình thường

### Test LED thành công:

- NumLock/CapsLock/ScrollLock LED phản hồi
- Có thông báo mode change trong dmesg

## Ghi chú quan trọng

1. **Chạy với quyền root**: Cần sudo để load/unload module
2. **Backup keyboard driver**: Driver này sẽ override USB keyboard hiện tại
3. **Test an toàn**: Có thể unload driver bất cứ lúc nào bằng `sudo rmmod usbkbd`
4. **Kernel compatibility**: Đã được sửa đổi cho kernel 2.6.32

## Tác giả

- **Driver Author**: Kma software developer
- **Compatibility**: Fixed for CentOS 6 kernel 2.6.32
