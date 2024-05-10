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

loadermsg db 'welcome to kernel.'

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
    mov cx,18
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
;-----------------加载内核，将磁盘中的内核移到内存的0x70000地址处---------------------
    mov eax, KERNEL_START_SECTOR  ;kernel.bin 所在的扇区号
    mov ebx, KERNEL_BIN_BASE_ADDR ;加载到内核的指定位置
    mov ecx, 200                   ;直接读取200个扇区

    call rd_disk_m_32
;-----------------启用分页机制---------------------
    call setup_page             ;使用创建页目录表和页表初始化

    sgdt [gdt_ptr]              ;将描述符表地址加入到内存gdt_ptr中，一会儿用新地址重新加载

    ;加载显示存储器段地址
    mov ebx, [gdt_ptr+2]       ;这个是GDT_BASE
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

    jmp SELECTOR_CODE:enter_kernel
enter_kernel:
    call kernel_init
    call set_cursor_newline     ;为了显示换行使用
    mov esp,0xc009f000          ;9f00-9fbff作为栈地址
    jmp KERNEL_ENTER_ADDR
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

;建立页表项PTE 一个页表相里面包含1024个页地址,这里是对低1M内容做映射
    mov eax,PAGE_DIR_TABLE_POS
    add eax,0x1000
    mov ecx,256                         ;这里是将1M内存分割成每页的大小
    mov esi,0                           ;循环地址自加
    mov edx,PG_US_U | PG_RW_W | PG_P    ;属性为 7，US=1，RW=1，P=1
.create_pte:
    mov [ebx+esi*4],edx                 ;这里为什么要*4呢？这是由于页目录项和页表项是12位的，所以要左移4位
    add edx,4096
    inc esi
    loop .create_pte

;加载内核其他的页表的PDE，对第768~1023做映射都指向真实物理内存的低1M
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
;-----------------初始化内核代码---------------------
;解析elf头文件，并且完成相应的代码读取
;将kernel中对应的段加载到指定的呢内存地址中去
kernel_init:
    ;第一步清除通用寄存器的值，准备代码初始化使用
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx

    mov dx,  [KERNEL_BIN_BASE_ADDR+42]   ;偏移文件 42 字节处的属性是 e_phentsize，表示 program header 大小
    mov ebx, [KERNEL_BIN_BASE_ADDR+28]   ;表示第 1 个 program header 在文件中的偏移量
    add ebx,  KERNEL_BIN_BASE_ADDR         ;将文件头段头表的地址加载到ebx中
    mov cx,  [KERNEL_BIN_BASE_ADDR+44]   ;有多少个段？

.each_segment:
    cmp dword [ebx+0], PT_NULL                ;判断这个段头表是否被使用,修改过4-30
    je .PTNULL
   ;添加的代码段，这里是补充的，但是我并不知道这里为啥要补充
    ;mov eax,[ebx+8]
    ;mov esi,0xc0001500
    ;cmp eax,esi
    ;jmp $
    ;jb .PTNULL

   ;为函数memcpy压入参数,参数是从右往左依然压入.函数原型类似于 memcpy(dst,src,size)
   push dword [ebx + 16]		          ;program header中偏移16字节的地方是p_filesz,压入函数memcpy的第三个参数:size
   mov eax, [ebx + 4]			          ;距程序头偏移量为4字节的位置是p_offset
   add eax, KERNEL_BIN_BASE_ADDR	      ;加上kernel.bin被加载到的物理地址,eax为该段的物理地址
   push eax				                  ;压入函数memcpy的第二个参数:源地址
   ;jmp $
   push dword [ebx + 8]			          ;压入函数memcpy的第一个参数:目的地址,偏移程序头8字节的位置是p_vaddr，这就是目的地址

   call mem_cpy				              ;调用mem_cpy完成段复制
   add esp,12				              ;清理栈中压入的三个参数
.PTNULL:
   add ebx, edx				              ;edx为program header大小,即e_phentsize,在此ebx指向下一个program header
   loop .each_segment
   ret

;----------  逐字节拷贝 mem_cpy(dst,src,size) ------------
;输入:栈中三个参数(dst,src,size)
;输出:无
;---------------------------------------------------------
mem_cpy:
   cld                                    ;清除方向的标志，通过将方向标志位设置为0，确保字符串操作向前移动
   push ebp
   mov ebp, esp                           ;将堆栈栈顶指针，赋值给ebp
   push ecx		                          ;rep指令用到了ecx，但ecx对于外层段的循环还有用，故先入栈备份
   mov edi, [ebp + 8]	                  ;dst
   mov esi, [ebp + 12]	                  ;src
   mov ecx, [ebp + 16]	                  ;size
   rep movsb		                      ;逐字节拷贝，movsb是字符串操作指令，将一个字节从源地址赋值到目标地址，在加上rep，就是赋值块

   ;恢复环境
   pop ecx                                ;弹出相应的环境变量
   pop ebp
   ret
;----------  读磁盘的操作函数 ------------
rd_disk_m_32:
    mov esi,eax                 ;备分al,这里备份的是地址
    mov di,cx                   ;备分扇区数

    mov dx,0x1f2
    mov al,cl   ;将要读取的扇区数设置在相应的寄存器中
    out dx,al   ;将扇区的开始地址放入到

    mov eax,esi ;这里是恢复相应的寄存器

    ;设置相应的地址寄存器
    mov dx,0x1f3
    out dx,al

    mov cx,0x8
    shr eax,cl  ;将扇区的地址右移动8位
    mov dx,0x1f4
    out dx,al

    shr eax,cl
    mov dx,0x1f5
    out dx,al


    shr eax,cl
    and al,0xf
    or  al,0xe0
    mov dx,0x1f6
    out dx,al

    ;配置device寄存器为LBA模式，并且选中磁盘0
    mov dx,0x1f7
    mov al,0x20
    out dx,al      ;这里其实不太清楚，为什么读命令为0x20

    ;检查硬盘是否正常工作
.not_ready:
    nop ;过渡一下，常用的操作
    in  al,dx      ;从寄存器中读出数据
    and al,0x88    ;相当于if判断
    cmp al,0x08
    jnz .not_ready

    ;读取数据，这里首先确定循环次数
    mov ax,di      ;把 di 储存的cx 取出来，这里是要读取几个硬盘
    mov dx,256     ;每次读出来2个字节，
    mul dx         ;与di 与 ax 做乘法 计算一共需要读多少次 方便作循环 低16位放ax 高16位放dx
    mov cx,ax      ;loop 与 cx相匹配 cx-- 当cx == 0即跳出循环
    mov dx,0x1f0   ;需要读取的地址

 .go_read_loop:
    in  ax,dx       ;两字节dx 一次读两字
    mov [ebx],ax    ;这里修改过，为什么要这么修改呢？目前还不太清楚
    add ebx,2
    loop .go_read_loop
    ret             ;与call 配对返回原来的位置 跳转到call下一条指令，表示函数结束


set_cursor_newline:
   push dx
   push ax
   ;将光标设为bx值
   ;1.先设置高8位
   mov dx,0x03d4           ;索引寄存器
   mov al,0x0e             ;光标位置高8位
   out dx,al
   mov dx,0x03d5           ;通过读写数据端口0x3d5来获得或设置光标位置
   mov al,0x00
   out dx,al

   ;2.再设置低8位
   mov dx,0x03d4
   mov al,0x0f
   out dx,al
   mov dx,0x03d5
   mov al,0xf0
   out dx,al
   pop ax
   pop dx
   ret
