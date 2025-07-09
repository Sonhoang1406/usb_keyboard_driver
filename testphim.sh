#!/bin/bash

echo "Nạp module..."
sudo insmod usbkbd.ko

echo "Gõ phím để kiểm tra..."
sleep 10  # Đợi người dùng gõ phím

# Lưu log vào biến
log=$(sudo dmesg | tail -20)

# Kiểm tra log xem module có được nạp thành công không
if echo "$log" | grep -q "usbkbd: loading out-of-tree module taints kernel"; then
    echo "Module usbkbd đã được nạp thành công."
else
    echo "Lỗi: Không thể nạp module usbkbd."
fi

# Hiển thị log
echo "$log"

# Kiểm tra log để xem các phím bấm có được nhận diện không
if echo "$log" | grep -q "Macro key pressed"; then
    echo "Phím macro đã được nhận diện."
else
    echo "Lỗi: Phím macro không được nhận diện."
fi

echo "Gỡ bỏ module..."
sudo rmmod usbkbd

# Lưu log vào biến sau khi gỡ bỏ
log=$(sudo dmesg | tail -20)

# Kiểm tra log xem module có được gỡ bỏ thành công không
if echo "$log" | grep -q "usbcore: deregistering interface driver usbkbd"; then
    echo "Module usbkbd đã được gỡ bỏ thành công."
else
    echo "Lỗi: Không thể gỡ bỏ module usbkbd."
fi

# Hiển thị log
echo "$log"

