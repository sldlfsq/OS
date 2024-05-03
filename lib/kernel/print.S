TI_GDT equ 0               ;定义段选择子相关权限
RPL0   equ 0               ;定义RPL位，这个和安全相关
SELECTOR_VIDEO equ (0x0003<<3)+TI_GDT+RPL0   ;定义显示器的段选择子

section .data
put_int_buffer dq 0        ;定义8字节缓冲区用于数字到字符的转换

[bits 32]
section .text
   ;-------------------- put_char ---------------------
   ;功能描述：把栈中的1个字符写入光标所在处
   ;---------------------------------------------------
global put_char:
put_char:
   pushad                  ;备份32位寄存器环境，需要保证gs为正确的视频段选择子，保险起见，每次打印时都为gs赋值
   mov ax,SELECTOR_VIDEO
   mov gs,ax

   ;获取当前光标位置
   ;先获取高8位
   mov dx,0x03d4            ;由于要对显示器的光标进行设置，选择Address Register的端口地址为0x3D4
   mov al,0x0e              ;al为选择的地址索引，该地址对应的是光标的高八位
   out dx,al
   mov dx,0x03d5            ;选择读取的寄存器的地址
   in al,dx                 ;从该地址中读取相应的高八位的值
   mov ah,al                ;将该值保存到ah中
   ;再获取低8位
   mov dx,0x03d4
   mov al,0x0f
   out dx,al
   mov dx,0x03d5
   in al,dx
   mov bx,ax                ;将光标存入bx

   ;--------------读出数值------------------------
   ;若为控制字符，则进行相应的操作，如换行，删除，空格等
   ;若为其他字符，则直接进行输出即可
   mov ecx,[esp+36]         ;pushad压入4*8=32B，加上主调函数4B的返回地址，故esp+36B

   cmp cl,0xd               ;CR是0x0d，LF是0x0a CR是回车，LF是换行的意思
   jz .is_carriage_return
   cmp cl,0xa
   jz .is_line_feed
   cmp cl,0x8              ;BS(backspace)的ASCII码是8
   jz .is_backspace
   jmp .put_other

.is_backspace:
   dec bx                  ;这里为什么要减少1呢，这是由于回车就是删除的意思
   shl bx,1                ;光标左移1位等于乘2，表示光标对应显存中的偏移字节
   mov byte [gs:bx],0x20   ;将待删除的字节补为0或空格皆可
   inc bx
   mov byte [gs:bx],0x07   ;设置背景格式
   shr bx,1
   jmp .set_cursor         ;设置光标格式

.put_other:
   shl bx,1                ;光标位置用2字节表示，将光标值*2表示对应显存中的偏移字节
   mov [gs:bx],cl          ;ASCII字符本身
   inc bx
   mov byte [gs:bx],0x07   ;字符属性
   shr bx,1                ;恢复老光标值
   inc bx                  ;下一个光标值
   cmp bx,2000
   jl .set_cursor          ;若光标值小于2000，表示未写到显存的最后，则去设置新的光>标值，若超出屏幕字符大小（2000），则换行处理
;这里回车换行是一起处理的，当满屏时，其实也是相当于回车换行，美区别
.is_line_feed:             ;换行符LF(\n)
.is_carriage_return:       ;回车符CR(\r)
   ;如果是CR(\r)，只要把光标移到行首就行了
   xor dx,dx               ;dx是被除数的高16位，清0
   mov ax,bx               ;ax是被除数的低16位
   mov si,80
   div si
   sub bx,dx               ;光标值取整

.is_carriage_return_end:
   add bx,80
   cmp bx,2000
.is_line_feed_end:         ;若是LF(\n)，将光标移+80即可
   jl .set_cursor

   ;屏幕行范围是0~24，滚屏的原理是将屏幕第1~24行搬运到第0~23行，再将第23行用空格填>充
.roll_screen:              ;若超出屏幕大小，滚屏
   cld
   mov ecx,960             ;2000-80=1920个字符，共1920*2=3840B，一次搬4B，共3840/4=960次
   mov esi,0xc00b80a0      ;第1行行首
   mov edi,0xc00b8000      ;第0行行首
   rep movsd

   ;将最后一行填充为空白
   mov ebx,3840
   mov ecx,80

.cls:
   mov word [gs:ebx],0x0720;0x0720是黑底白字的空格键
   add ebx,2
   loop .cls
   mov bx,1920             ;将光标值重置为1920，最后一行首字符

.set_cursor:
   ;将光标设为bx值
   ;1.先设置高8位
   mov dx,0x03d4           ;索引寄存器
   mov al,0x0e             ;光标位置高8位
   out dx,al
   mov dx,0x03d5           ;通过读写数据端口0x3d5来获得或设置光标位置
   mov al,bh
   out dx,al

   ;2.再设置低8位
   mov dx,0x03d4
   mov al,0x0f
   out dx,al
   mov dx,0x03d5
   mov al,bl
   out dx,al
.put_char_done:
   popad
   ret


;----------------打印字符串 ---------------
global put_str:
put_str:
   push ebx                  ;使用ebx，来记录字符串的地址
   push ecx                  ;使用ecx，来记录打印的值
   xor ecx,ecx
   mov ebx,[esp+12]
.put_char_loop:
   mov cl,[ebx]
   cmp cl,0                  ;判断是否是结束的字符串，默认会结尾/0
   jz .str_over
   push ecx                  ;将待打印的数据压入栈中
   call put_char
   add esp,4
   inc ebx
   jmp .put_char_loop
.str_over:
   pop ecx
   pop ebx
   ret

;----------------打印整数，不知道有沙用 ---------------
global put_int
put_int:
   pushad
   mov ebp,esp
   mov eax,[esp+36]        ;32B+4B返回地址
   mov edx,eax
   mov edi,7               ;put_int_buffer偏移量
   mov ecx,8               ;循环八次
   mov ebx,put_int_buffer

.16based_4bits:
   and edx,0x0000000F
   cmp edx,9
   jg  .is_A2F             ;A～F的ASCII码
   add edx,'0'             ;0~9的ASCII码
   jmp .store

.is_A2F:
   sub edx,10
   add edx,'A'             ;减去10等于A～F的字符序+'A'得ASCII码
.store:
   mov [ebx+edi],dl        ;此时dl中是数字对应字符的ASCII码
   dec edi
   shr eax,4
   mov edx,eax
   loop .16based_4bits

.ready_to_print:
   inc edi                 ;edi减退为-1
.skip_prefix_0:            ;跳过前导0
   cmp edi,8               ;edi偏移量为8的时候表示到了第9个字符
   je .full0               ;前导0有8个，说明全是0

.go_on_skip:
   mov cl,[put_int_buffer+edi]
   inc edi                 ;下一个字符
   cmp cl,'0'
   je .skip_prefix_0       ;判断下一个字符是否为'\0'
   dec edi                 ;不是'\0'，edi减1恢复当前字符
   jmp .put_each_num

.full0:
   mov cl,'0'              ;全为0，输出一个0即可
.put_each_num:
   push ecx
   call put_char
   add esp,4
   inc edi                 ;使edi指向下一个字符
   mov cl,[put_int_buffer+edi]
   cmp edi,8
   jl .put_each_num
   popad
   ret
