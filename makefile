BUILD_DIR = ./build
ENTRY_POINT = 0xc0001500
AS = nasm
CC = gcc
LD = ld
LIB = -I lib/ -I lib/kernel/ -I lib/user/ -I kernel/ -I device/ -I kernel/device -I kernel/thread
ASFLAGS = -f elf
#Wall: 开启编译器的警告提示，可以帮助发现代码中的一些潜在问题。
#-m32: 指定生成32位的目标代码。
#-fno-stack-protector: 禁用栈保护功能，即禁止编译器对栈进行保护。
#-c: 仅进行编译，不进行链接操作，生成目标文件。
#-fno-builtin: 禁止使用内建函数，强制使用用户自定义的函数。
#-W, -Wstrict-prototypes, -Wmissing-prototypes: 启用额外的警告提示，如函数原型检查等。
#
#
CFLAGS = -Wall -m32 -fno-stack-protector $(LIB) -c -fno-builtin -W -Wstrict-prototypes -Wmissing-prototypes
LDFLAGS =  -m elf_i386 -Ttext $(ENTRY_POINT) -e main -o $(BUILD_DIR)/kernel.bin
OBJS = $(BUILD_DIR)/main.o $(BUILD_DIR)/init.o $(BUILD_DIR)/interrupt.o \
       $(BUILD_DIR)/timer.o $(BUILD_DIR)/kernel.o $(BUILD_DIR)/print.o \
       $(BUILD_DIR)/debug.o $(BUILD_DIR)/string.o $(BUILD_DIR)/bitmap.o \
	   $(BUILD_DIR)/memory.o $(BUILD_DIR)/thread.o $(BUILD_DIR)/switch.o \
	   $(BUILD_DIR)/list.o
##############     c代码编译     ###############
$(BUILD_DIR)/main.o: kernel/main.c
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/init.o: kernel/init.c
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/interrupt.o: kernel/device/interrupt.c
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/timer.o: kernel/device/timer.c
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/debug.o: kernel/device/debug.c
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/string.o: lib/kernel/string.c
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/bitmap.o: kernel/device/bitmap.c
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/memory.o: kernel/device/memory.c
	$(CC) $(CFLAGS) $< -o $@
	
$(BUILD_DIR)/thread.o: kernel/thread/thread.c
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/list.o: kernel/thread/list.c
	$(CC) $(CFLAGS) $< -o $@

##############    汇编代码编译    ###############
$(BUILD_DIR)/kernel.o: kernel/device/kernel.S
	$(AS) $(ASFLAGS) $< -o $@

$(BUILD_DIR)/print.o: lib/kernel/print.S
	$(AS) $(ASFLAGS) $< -o $@

$(BUILD_DIR)/switch.o: kernel/thread/switch.S
	$(AS) $(ASFLAGS) $< -o $@


##############    链接所有目标文件    #############
$(BUILD_DIR)/kernel.bin: $(OBJS)
	$(LD) $(LDFLAGS) $^ -o $@

.PHONY : mk_dir hd clean all

mk_dir:
	if [ ! -d $(BUILD_DIR) ]; then mkdir $(BUILD_DIR); fi

hd:
	sudo dd if=//home/chen/OS/build/kernel.bin of=//home/bochs/bochs/bin/hd60M.img bs=512 count=200 seek=9 conv=notrunc

clean:
	cd build && rm -f  ./*

build: $(BUILD_DIR)/kernel.bin

all: mk_dir build hd
