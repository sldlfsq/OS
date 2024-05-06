SRCS = init.c interrupt.c main.c
OBJS = $(SRCS:.c=.o)

all:
	gcc -m32 -I lib/kernel/ -m32 -I lib/ -m32 -I kernel/ -m32 -I kernel/device/ -c -fno-builtin -o build/main.o kernel/main.c
	gcc -m32 -I lib/kernel/ -m32 -I lib/ -m32 -I kernel/ -m32 -I kernel/device/ -c -fno-builtin -o build/interrupt.o kernel/device/interrupt.c
	gcc -m32 -I lib/kernel/ -m32 -I lib/ -m32 -I kernel/ -m32 -I kernel/device/ -c -fno-builtin -o build/timer.o kernel/device/timer.c
	gcc -m32 -I lib/kernel/ -m32 -I lib/ -m32 -I kernel/ -m32 -I kernel/device/ -c -fno-builtin -o build/init.o kernel/init.c
	nasm -f elf -o build/print.o lib/kernel/print.S
	nasm -f elf -o build/kernel.o kernel/device/kernel.S
	ld -m elf_i386 -Ttext 0xc0001500 -e main -o build/kernel.bin build/main.o build/init.o build/interrupt.o build/print.o build/kernel.o build/timer.o
	sudo dd if=//home/chen/OS/build/kernel.bin of=//home/bochs/bochs/bin/hd60M.img bs=512 count=200 seek=9 conv=notrunc

clean:
	rm -f build/*.o build/kernel.bin
