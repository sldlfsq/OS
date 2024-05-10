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
#include "memory.h"
#include "thread.h"

//声明线程的函数
void thread_one(void* arg);
int main() {
    char* str = "hello,world!\n";
    char* para = "i am fatehr ji ";
    void *addr;
    put_str("i am kernel\n");
    init_all();
    int length = strlen(str);
    put_str(str);
    thread_start("thread_one", 31, thread_one, para);
    // put_int(length);
    // ASSERT(2==2);
    // addr = get_kernel_pages(2);
    // put_int((uint32_t)addr);
    // (void)interrupt_set_status(INTERRUPT_ON);
    while (1);
    return 0;
}

void thread_one(void* arg){

    char *para = (char *)arg;
    while(1)
    {
        put_str(para);
    }
}
