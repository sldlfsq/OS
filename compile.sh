#!/bin/bash

echo "start comile boot 相关文件"
cd ./boot
nasm -I include/ -o mbr2.bin mbr2.S
nasm -I include/ -o loader.bin loader.S
sudo dd if=//home/chen/OS/boot/mbr2.bin of=//home/bochs/bochs/bin/hd60M.img bs=512 count=1 conv=notrunc
sudo dd if=//home/chen/OS/boot/loader.bin of=//home/bochs/bochs/bin/hd60M.img bs=512 count=3 seek=2 conv=notrunc
echo "comile finish"
