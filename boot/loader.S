%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR     ;这个宏定义是什么意思呢？
jmp loader_start


;构建描述符，这里是数据段，代码会被放在内存中的数据段中
GDT_BASE: dd 0x00000000
          dd 0x00000000

CODE_DESC: dd 0x0000ffff
           dd DESC_CODE_HIGH4

DATA_STACK_DESC: dd 0x0000FFFF
                 dd DESC_DATA_HIGH4

VIDEO_DESC: dd 0x80000007       ;显存的地址为0xb8000-0xbffff,段界限可以容易得出为07fff/4k = 7
            dd DESC_VIDEO_HIGH4

GDT_SIZE  equ $ - GDT_BASE      ;这里是为什么呢？，宏定义在编译时就会被替换，不占用内存
GDT_LIMIT equ GDT_SIZE - 1

times 60 dq 0x1111         ;预留60个描述符的空位，这里是编译器执行，而非CPU执行，可以认为这里就是在定义变量而已，变量会被放在什么地方呢？应该是数据段

total_mem_bytes dd 0x2b147b98  ;上面占了512个字节，所以这里的偏移地址就是0x203
;GDT指针

gdt_ptr dw GDT_LIMIT
        dd GDT_BASE

ards_buf times 244 db 0 ;这里用来记录ARDS描述符，为了也是为了凑256字节
ards_nr dw 0            ;这里用来记录ARDS结构体数量

;段选择子
SELECTOR_CODE  equ (0x0001<<3) + TI_GDT + RPL0 ;全局描述符第一个就是代码段
SELECTOR_DATA  equ (0x0002<<3) + TI_GDT + RPL0 ;全局描述符第二个就是数据段
SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0 ;全局描述符第二个就是显存段

loadermsg db 'loader in real.'

loader_start:

;-----------------显示内存，0xE820功能号---------------------
    xor ebx,ebx                             ;异或清零
    mov edx,0x534d4150
    mov di,ards_buf
.e820_mem_get_loop:                         ;循环读取内存中的内容到目的内存中
    mov eax,0x0000e820
    mov eax,0x0000e820
    int 0x15
    add di,cx
    inc word [ards_nr]
    cmp ebx,0
    jnz .e820_mem_get_loop

;-----------------找出一个连续内存能使用最大的块---------------------
;理论上直接使用冒泡法来实现即可，但是汇编的冒泡法也太难了
    mov cx,[ards_nr]
    mov ebx,ards_buf                        ;ards_buf的首地址
    xor edx,edx
.find_max_mem_area:
    mov eax,[ebx]
    add eax,[ebx+8]
    add ebx,20
    cmp edx,eax
    jge .next_ards
    mov edx,eax

.next_ards:
    loop .find_max_mem_area
    jmp .mem_get_ok

.mem_get_ok:
    mov [total_mem_bytes],edx

;-----------------显示字符串---------------------
;使用功能号为13的来打印字符串
    mov sp,LOADER_BASE_ADDR					;这里疑惑了我许久 es我们没有初始化 值究竟是多 为什么等于cs
    mov bp,loadermsg                        ;es:bp 字符串地址 ah 功能号 bh 页码 bl 属性 cx 字符串长度
    mov cx,16
    mov ax,cs                               ;于是我还是向把es给初始化了一下 保证心里面有底
    mov es,ax                               ;通过ax 赋值给es
    mov ax,0x1301                           ;ah = 13 al = 0x1
    mov bx,0x001f                           ;页码属性 可以不管
    mov dx,0x0200                           ;dh = 0x18 == 24 意思是最后一行 0列开始
    int 0x10
;-----------------准备进入保护模式---------------------
    ;打开A20总线
    in al,0x92
    or al,0000_0010B
    out 0x92,al

    ;加载GDT
    lgdt [gdt_ptr]

    ;打开保护模式
    mov eax,cr0                              ;cr0寄存器第0位设置位1
    or  eax,0x00000001
    mov cr0,eax

;-----------------已经打开保护模式，开始32位寻址---------------------
    jmp dword SELECTOR_CODE:p_mode_start     ;SELECTOR_CODE为段选择子，p_mode_start为偏移地址

[bits 32] ;代表以下代码为32位
p_mode_start:
    ;设置寄存器的初始状态，我也不知道为什么要设置
    mov ax,SELECTOR_DATA
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov esp,LOADER_STACK_TOP
    mov ax,SELECTOR_VIDEO
    mov gs,ax

    mov byte [gs:160],'h'
    mov byte [gs:162],'e'
    jmp $     ;死循环
