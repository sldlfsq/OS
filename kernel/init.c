/*
 * Author: yanji
 * File: init.c
 * Description:inition of kernel
 * Date: 2024/5/5
 */
#include "print.h"
#include "interrupt.h"
#include "timer.h"
#include "memory.h"
void init_all() {
    put_str("init_all\n");
    idt_init();  // 初始化中断
    timer_init();
    mem_init();//内存池初始化
    thread_init();
}
