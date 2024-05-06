#ifndef __KERNEL_INTERRUPT_H
#define __KERNEL_INTERRUPT_H
#include "stdint.h"
/*
    空指针的用处：
    1、表明该变量是地址
    2、可以用于类型强转，面向对象编成可以使用
*/
typedef void* intr_handler;
typedef void (*interrupt_handler)(uint8_t vec_nr);
void idt_init(void);
void interrupt_register(uint8_t vec_nr, interrupt_handler function, char* name);

//定义中断的状态
//INTERRUPT_OFF 表示中断关闭
//INTERRUPT_ON 表示中断开启
typedef enum{  // 中断状态
    INTERRUPT_OFF,
    INTERRUPT_ON
} interrupt_status;

interrupt_status interrupt_get_status(void);
interrupt_status interrupt_set_status(interrupt_status status);
interrupt_status interrupt_enable(void);
interrupt_status interrupt_disable(void);
#endif
