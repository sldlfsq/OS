#include "kernel/print.h"
#include "init.h"
#include "thread/thread.h"
#include "interrupt.h"
#include "console.h"
#include "ioqueue.h"
#include "keyboard.h"
void k_thread_function_a(void*);
void k_thread_function_b(void*);
void k_thread_function_c(void*);

int main(void) {
    // 这里不能使用console_put_str，因为还没有初始化
    put_str("I am kernel.\n");
    init_all();

    thread_start("k_thread_a", 31, k_thread_function_a, "aa ");
    thread_start("k_thread_b", 31, k_thread_function_b, "bb ");
    // thread_start("k_thread_c", 31, k_thread_function_c, "cc ");
    intr_enable();
    int test = 100000;
    while (1) {
        // console_put_str("dd ");
        // intr_disable();

    }

    return 0;
}
char thead_a[64] = {0};
void k_thread_function_a(void* args) {
    // 这里必须是死循环，否则执行流并不会返回到main函数，所以CPU将会放飞自我，出发6号未知操作码异常
    while (1) {
        intr_disable();
        char a = ioq_getchar(&kbd_buf);
        console_put_char(a);
        intr_enable();
        // console_put_str((char*) args);
    }
}

void k_thread_function_b(void* args) {
    while (1) {
        // console_put_str((char*) args);
        // 阻塞进程，之后只会有一个进程的存在
        // thread_block(TASK_BLOCKED);
    }
}

void k_thread_function_c(void* args) {
    while (1) {
        console_put_str((char*)args);
        // thread_block(TASK_BLOCKED);
    }
}
