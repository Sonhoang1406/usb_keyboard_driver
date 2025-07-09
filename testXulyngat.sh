#!/bin/bash

echo "Nạp module..."
sudo insmod usbkbd.ko

echo "Kiểm tra log hệ thống trước khi gõ phím..."
log_before=$(sudo dmesg | tail -40)
echo "$log_before"

echo "Gõ phím để kiểm tra ngắt..."
# Gõ một số phím và kiểm tra log
sleep 10  # Đợi người dùng gõ phím

echo "Kiểm tra log hệ thống sau khi gõ phím..."
log_after=$(sudo dmesg | tail -40)
echo "$log_after"

echo "So sánh log trước và sau khi gõ phím..."
diff_output=$(diff <(echo "$log_before") <(echo "$log_after"))

if [ -z "$diff_output" ]; then
    echo "Không có sự khác biệt giữa log trước và sau khi gõ phím. Ngắt có thể chưa được xử lý đúng cách."
else
    echo "Có sự khác biệt giữa log trước và sau khi gõ phím. Ngắt đã được xử lý:"
    echo "$diff_output"
fi

echo "Gỡ bỏ module..."
sudo rmmod usbkbd

echo "Kiểm tra log hệ thống sau khi gỡ module..."
sudo dmesg | tail -20

