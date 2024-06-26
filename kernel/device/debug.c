/*
 * Author: yanji
 * File: debug.c
 * Description: 实现assert宏
 * Date: 2024/5/6
 */
#include "debug.h"
#include "interrupt.h"
#include "print.h"

/* 打印文件名、行号、函数名、条件并使程序悬停 */
void panic_spin(char* filename, int line, const char* func ,const char* condition) {
    (void)interrupt_disable();  // 因为有时候会单独调用panic_spin，所以在此处关中断
    put_str("\n\n\n!!!!! error !!!!!\n");
    put_str("filename:");
    put_str(filename);
    put_str("\n");
    put_str("ilne:0x");
    put_int(line);
    put_str("\n");
    put_str("function:");
    put_str(func);
    put_str("\n");
    put_str("condition:");
    put_str(condition);
    put_str("\n");
    while (1);
}
