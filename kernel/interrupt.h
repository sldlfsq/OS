#ifndef __KERNEL_INTERRUPT_H
#define __KERNEL_INTERRUPT_H
#include "stdint.h"
/*
    空指针的用处：
    1、表明该变量是地址
    2、可以用于类型强转，面向对象编成可以使用
*/
typedef void* intr_handler;
void idt_init(void);
#endif
