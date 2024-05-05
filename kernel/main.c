/*
 * Author: yanji
 * File: main.c
 * Description:
 * Date: 2024/5/4
 */

#include "print.h"
#include "init.h"
int main()
{
    put_str("i am kernel\n");
    put_int(0x12345678);
    init_all();
    asm volatile("sti");  // 为演示中断处理,在此临时开中断
    while(1);
    return 0;
}
