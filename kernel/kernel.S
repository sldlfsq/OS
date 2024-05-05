;这段代码实现的功能：
;1、建立中断向量表，并且在中断向量表中填入每个中断的地址
;2、定义每个中断的中断服务函数，主要就是打印“中断发生的字符”
;3、将中断向量表全局化
[bits 32]
%define ERROR_CODE nop      ;nop空指令，程序空运行一段时间
%define ZERO push 0

extern put_str              ;声明外部函数，在汇编中是这样声明的

section .data
intr_str db "interrupt occur!",0xa,0
global intr_entry_table
intr_entry_table:           ;这里是定义了一个数组？

%macro VECTOR 2
section .text
intr%1entry:                ;每个中断处理程序都要压入中断向量号，一个中断类型一个中断处理程序
   %2                       ;手动压入错误码，使得函数调用一致

   push intr_str            ;调用字符串打印函数
   call put_str
   add esp,4                ;跳过参数

   ;如果是从片上进入的中断，除了往从片上发送EOI外，还要往主片上发送EOI
   ;这里往主片和从片上写入EIO，表示中断处理完成
   mov al,0x20              ;中断结束命令EOI
   out 0xa0,al              ;向从片发送
   out 0x20,al              ;向主片发送
   add esp,4                ;跳过error_code

   iret                     ;从中断返回

section .data
   dd intr%1entry           ;存储各个中断入口程序的地址，形成intr_entry_table数组，注意这里是4个字节，但是不是说是8个字节吗？
%endmacro
;------------------初始化中断向量符表------------------------
VECTOR 0x0 ,ZERO
VECTOR 0x1 ,ZERO
VECTOR 0x2 ,ZERO
VECTOR 0x3 ,ZERO
VECTOR 0x4 ,ZERO
VECTOR 0x5 ,ZERO
VECTOR 0x6 ,ZERO
VECTOR 0x7 ,ZERO
VECTOR 0x8 ,ERROR_CODE
VECTOR 0x9 ,ZERO
VECTOR 0xA ,ERROR_CODE
VECTOR 0xB ,ERROR_CODE
VECTOR 0xC ,ERROR_CODE
VECTOR 0xD ,ERROR_CODE
VECTOR 0xE ,ERROR_CODE
VECTOR 0xF ,ZERO
VECTOR 0x10 ,ZERO
VECTOR 0x11 ,ERROR_CODE
VECTOR 0x12 ,ZERO
VECTOR 0x13 ,ZERO
VECTOR 0x14 ,ZERO
VECTOR 0x15 ,ZERO
VECTOR 0x16 ,ZERO
VECTOR 0x17 ,ZERO
VECTOR 0x18 ,ZERO
VECTOR 0x19 ,ZERO
VECTOR 0x1A ,ZERO
VECTOR 0x1B ,ZERO
VECTOR 0x1C ,ZERO
VECTOR 0x1D ,ZERO
;------------------定义格式如下-------------
;0x1E 表示的是中断号
;ERROR_CODE 表示的是错误码
;20-31中断号不是保留了吗，为什么还要启用呢？？
VECTOR 0x1E ,ERROR_CODE
VECTOR 0x1F ,ZERO
VECTOR 0x20 ,ZERO   ;后续我们会使用这个中断号对外部中断进行处理，但是这个程序的入口地址在那里呢？
