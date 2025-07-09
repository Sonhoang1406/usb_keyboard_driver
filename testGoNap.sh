#!/bin/bash

# Test việc nạp module
./load.sh
if lsmod | grep "usbkbd" &> /dev/null ; then
    echo "Module nạp thành công"
else
    echo "Module không nạp được"
fi

# Kiểm tra việc xử lý phím bấm
# Gõ vài phím và kiểm tra dmesg hoặc log của hệ thống để xác nhận rằng các phím được nhận diện đúng cách
dmesg | tail -20

# Gỡ bỏ module
./unload.sh
if lsmod | grep "usbkbd" &> /dev/null ; then
    echo "Module không gỡ bỏ được"
else
    echo "Module gỡ bỏ thành công"
fi

