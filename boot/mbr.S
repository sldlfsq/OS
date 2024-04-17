SECTION MBR vstart=0x7c00 ;起始地址编译在0x7c00,这个其实是这个计算是如何计算的作者也只是猜测的
    mov ax,cs
    mov ds,ax    ;数据段
    mov es,ax    ;扩展数据段
    mov ss,ax    ;栈段
    mov fs,ax    ;数据段
    mov sp,0x7c00
    ;这个时候 ds = es = ss = 0 栈指针指向MBR开始位置


    ;ah = 0x06 al = 0x00 想要调用int 0x06的BIOS提供的中断对应的函数 即向上移动即完成清屏功能
    ;cx dx 分别存储左上角与右下角的左边 详情看int 0x06函数调用
    mov ax,0x600
    mov bx,0x700
    mov cx,0
    mov dx,0x184f

    ;调用BIOS中断
    int 0x10

    mov ah,3
    mov bh,0

    ;获取光标位置 需要打印信息
    int 0x10

    mov ax,message
    mov bp,ax

    mov cx,5
    mov ax,0x1301

    mov bx,0x71;白底蓝字好cooi

    int 0x10 ;写字符串

    jmp $ ;无限循环 一直跳转到当前命令位置

    ;字符串声明 db == define byte dw == define word ascii一个字符占一个字节
    message db "1 MBR start work"

    ;预留两个字节 其余空余的全部用0填满 为使检测当前扇区最后两字节为0x55 0xaa 检测是否为有效扇区
    ;510 = 512字节-2预留字节  再减去（当前位置偏移量-段开始位置偏移量）求出来的是剩余空间
    times 510 - ($ - $$) db 0 ;times 主要用于填充空间、重复定义数据或其他类似的场景
    db 0x55,0xaa
