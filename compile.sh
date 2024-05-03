#!/bin/bash

echo "start comile boot 相关文件"

# nasm -I boot/include/ -o boot/mbr2.bin boot/mbr2.S
# nasm -I boot/include/ -o boot/loader.bin boot/loader.S

nasm -f elf -o lib/kernel/print.o lib/kernel/print.S
# sudo dd if=//home/chen/OS/boot/mbr2.bin of=//home/bochs/bochs/bin/hd60M.img bs=512 count=1 conv=notrunc
# sudo dd if=//home/chen/OS/boot/loader.bin of=//home/bochs/bochs/bin/hd60M.img bs=512 count=3 seek=2 conv=notrunc

gcc -m32 -I lib/kernel/ -c -o kernel/main.o kernel/main.c
# ld -m elf_i386 main.o -Ttext 0xc0001500 -e main -o kernel.bin
ld -m elf_i386 -Ttext 0xc0001500 -e main -o kernel/kernel.bin kernel/main.o lib/kernel/print.o
sudo dd if=//home/chen/OS/kernel/kernel.bin of=//home/bochs/bochs/bin/hd60M.img bs=512 count=200 seek=9 conv=notrunc
echo "comile finish"
