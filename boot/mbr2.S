;这个文件是直接对显存进行操作

%include "boot.inc";包含头文件
SECTION MBR vstart=0x7c00 ;起始地质编译在0x7c00
    mov ax,cs
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov fs,ax
    mov sp,0x7c00
    mov ax,0xb800 ; ax为文本信号起始区,也就是显示的内存区域
    mov gs,ax     ; gs = ax 充当段基址的作用

    ;ah = 0x06 al = 0x00 想要调用int 0x10的BIOS提供的中断对应的函数 即向上移动即完成清屏功能
    ;cx dx 分别存储左上角与右下角的左边 详情看int 0x10函数调用
    ;这里是用寄存器来存储中断调用时的参数
    mov ax,0600h  ; 清屏
    mov bx,0700h  ; 屏幕大小信息
    mov cx,0      ; 文本滚动行数开始位置
    mov dx,184fh  ; 结束位置

    ;调用BIOS中断
    int 0x10      ; 对屏幕操作的指令

    ;新增功能 直接操作显存部分
    ;预设输出yanji.chen
    ;这里使用段跨越前缀，GS代替默认的数据段DS
    mov byte [gs:0x00],'Y' ;低位字节储存ascii字符 小端储存内存顺序相反
    mov byte [gs:0x01],0xA4    ;背景储存在第二个字节 含字符与背景属性

    mov byte [gs:0x02],'A'
    mov byte [gs:0x03],0xA4

    mov byte [gs:0x04],'N'
    mov byte [gs:0x05],0xA4

    mov byte [gs:0x06],'J'
    mov byte [gs:0x07],0xA4

    mov byte [gs:0x08],'I'
    mov byte [gs:0x09],0xA4

    mov byte [gs:0x0A],'C'
    mov byte [gs:0x0B],0xA4

    mov byte [gs:0x0C],'H'
    mov byte [gs:0x0D],0xA4

    mov byte [gs:0x0E],'E'
    mov byte [gs:0x0F],0xA4

    mov byte [gs:0x10],'N'
    mov byte [gs:0x11],0xA4

;;;;;;;;;;;;;;;;;;;;;;;;;
;以下是新增部分 4-18
;;;;;;;;;;;;;;;;;;;;;;;;;
    ;用来存函数的入口参数
    mov eax,LOADER_START_SECTOR ;这个值是多少呢？,eax是存储的输送的信息，扇区的开始地址
    mov bx,LOADER_BASE_ADDR     ;内存存储的是目标位置

    mov cx,4                    ;读取磁盘数 cx常作计数

    ;mov esi,eax                ;备分al
    ;mov di,cx                  ;备分扇区数

    call rd_disk_m_16           ;执行完之后直接跳转
    jmp LOADER_BASE_ADDR
;;;;;;;;;;;;;;;;;;;;;;;;;;
;读取硬盘扇区操作函数
;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;下面是对磁盘操作的部分
rd_disk_m_16:

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
    mov [bx],ax
    add bx,2
    loop .go_read_loop
    ret             ;与call 配对返回原来的位置 跳转到call下一条指令，表示函数结束

    times 510 - ($ - $$) db 0
    db 0x55,0xaa
