%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR     ;这个宏定义是什么意思呢？
jmp loader_start                          ;这里的地址是0x00


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

times 59 dq 0x0         ;预留60个描述符的空位，这里是编译器执行，而非CPU执行，可以认为这里就是在定义变量而已，变量会被放在什么地方呢？应该是数据段
times 5 db 0

total_mem_bytes dd 0x0  ;上面占了512个字节，所以这里的偏移地址就是0x200
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
    mov eax,cr0                             ;cr0寄存器第0位设置位1
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
    mov byte [gs:162], 'C'

;-----------------启用分页机制---------------------
    call setup_page             ;使用创建页目录表和页表初始化

    sgdt [gdt_ptr]              ;将描述符表地址加入到内存gdt_ptr中，一会儿用新地址重新加载

    ;加载显示存储器段地址
    mov ebx, [gdt_ptr+2]      ;这个是GDT_BASE
    or dword [ebx+0x18+4], 0xc0000000   ;相当于段地址的最高位加C？   这里是干麻呢？

    add dword [gdt_ptr+2], 0xc0000000 ;全局描述符放到内核中去
    add esp, 0xc0000000         ;将栈指针同样映射到内核地址

    mov eax, PAGE_DIR_TABLE_POS ;将页目录地址赋值给cr3
    mov cr3, eax
    ;打开cr0的PG位
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax


    lgdt [gdt_ptr]              ;重新加载段基地址，由于GDT开启分页之后，地址会改变，所以这里加载新的地址

    mov byte [gs:160], 'V'

    jmp $     ;死循环

;-----------------以下是函数部分---------------------


;-----------------设置页表项和页表目录---------------------
setup_page:
    ;首先就是对也表目录项进行清零
    mov ecx,4096                                             ;循环4096次 将页目录项清空 内存清0
    mov esi,0
.clear_page_dir_mem:                                          ;dir directory 把页目录项清空
    mov byte [PAGE_DIR_TABLE_POS+esi],0
    inc esi
    loop .clear_page_dir_mem

;创建页目录项 PDE
.create_pde:
    mov eax,PAGE_DIR_TABLE_POS
    add eax,0x1000                     ;第一个起始页表的开始位置
    mov ebx,eax                        ;此处为 ebx 赋值，是为.create_pte 做准备，ebx 为基址

    or eax,PG_US_U | PG_RW_W | PG_P    ;设置页表属性 |最低特权级|可读写|存在

    mov [PAGE_DIR_TABLE_POS + 0x0],eax ;在第一个页表目录相的地方填入页表的位置和属性
    mov [PAGE_DIR_TABLE_POS + 0xc00],eax ;这里为什么这么做我还是存在疑问，为啥要在这里写入相同的地址呢？ Question-2024/4/24
    sub eax,0x1000
    mov [PAGE_DIR_TABLE_POS+4092],eax  ;最后一个页目录项指向页目录自己
    ;这里是进行了计算的，是由于内核亚要存放在用户空间的一个G里面，剩下的三个G是给用户空间的
    ;0x0——3G是用户空间

;建立页表项PTE 一个页表相里面包含1024个页地址
    mov ecx,256                         ;这里是将1M内存分割成每页的大小
    mov esi,0                           ;循环地址自加
    mov edx,PG_US_U | PG_RW_W | PG_P    ;属性为 7，US=1，RW=1，P=1
.create_pte:
    mov [ebx+esi*4],edx                 ;这里为什么要*4呢？这是由于页目录项和页表项是12位的，所以要左移4位
    add edx,4096
    inc esi
    loop .create_pte

;加载内核其他的页表的PDE
    mov eax, PAGE_DIR_TABLE_POS
    add eax, 0x2000                     ;此时 eax 为第二个页表的位置
    or eax, PG_US_U | PG_RW_W | PG_P    ;页目录项的属性 US､ RW 和 P 位都为 1
    mov ebx, PAGE_DIR_TABLE_POS
    mov ecx, 254                        ;范围为第769～1022的所有目录项数量 内核是从769 - 1023的，这里没有换算成线性地址
    mov esi, 769
.create_kernel_pde:
    mov [ebx+esi*4], eax
    inc esi
    add eax, 0x1000
    loop .create_kernel_pde

    ret
