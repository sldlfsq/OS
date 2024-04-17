;这个文件是直接对显存进行操作

SECTION MBR vstart=0x7c00 ;起始地质编译在0x7c00
    mov ax,cs
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov fs,ax
    mov sp,0x7c00
    mov ax,0xb800 ; ax为文本信号起始区
    mov gs,ax     ; gs = ax 充当段基址的作用

    ;ah = 0x06 al = 0x00 想要调用int 0x10的BIOS提供的中断对应的函数 即向上移动即完成清屏功能
    ;cx dx 分别存储左上角与右下角的左边 详情看int 0x10函数调用
    ;这里是用寄存器来存储中断调用时的参数
    mov ax,0600h  ; 清屏
    mov bx,0700h  ; 屏幕大小信息
    mov cx,0      ; 文本滚动行数开始位置
    mov dx,184fh  ; 结束位置

    ;调用BIOS中断
    int 0x10

    ;新增功能 直接操作显存部分
    ;预设输出LOVE6 OS
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

    jmp $ ;于此处死循环

    times 510 - ($ - $$) db 0
    db 0x55,0xaa
