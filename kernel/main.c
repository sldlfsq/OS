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
int main()
{
    put_str("i am kernel\n");
    init_all();
    ASSERT(1==2);
    // (void)interrupt_set_status(INTERRUPT_ON);
    while(1);
    return 0;
}
