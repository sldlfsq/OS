/*
 * Author: yanji
 * File: main.c
 * Description:
 * Date: 2024/5/4
 */
#include "print.h"
#include "init.h"
#include "timer.h"
#include "interrupt.h"
#include "debug.h"
#include "string.h"
int main()
{
    char* str = "hello,world!\n";
    put_str("i am kernel\n");
    init_all();
    int length = strlen(str);
    put_str(str);
    put_int(length);
    ASSERT(2==2);
        // (void)interrupt_set_status(INTERRUPT_ON);
    while (1);
    return 0;
}
