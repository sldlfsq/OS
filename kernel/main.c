#include "print.h"
#include "init.h"
#include "timer.h"
#include "interrupt.h"
#include "debug.h"
#include "string.h"
#include "memory.h"
#include "thread.h"
#include "console.h"
//声明线程的函数
void thread_one(void* arg);
void thread_two(void* arg);
int main() {
    char* str = "hello,world!\n";
    char* para = "qaq ";
    char* para2 = "waw ";
    char* para3 = "mmu ";
    init_all();
    thread_start("thread_one", 31, &thread_one, para);
    thread_start("thread_two", 31, &thread_two, para2);
    interrupt_enable();
    while (1){
        console_put_str("sadsdfasdasd ");
    }
    return 0;
}

void thread_one(void* arg){

    char *para = (char *)arg;
    while(1)
    {
        console_put_str("wosdasdqu ");
    }
}

void thread_two(void* arg) {

    char* para = (char*)arg;
    while (1) {
        console_put_str("mmmm ");
    }

}
