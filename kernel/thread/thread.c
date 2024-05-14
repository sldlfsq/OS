#include "thread.h"
#include "list.h"
#include "interrupt.h"
#include "debug.h"
#include "global.h"
#include "memory.h"
#include "stdint.h"
#include "string.h"
#include "thread.h"
#include "print.h"
#define PG_SIZE 4096

struct task_struct* main_thread;  // 主线程 PCB
struct list thread_ready_list;  // 就绪队列
struct list thread_all_list;  // 任务队列
static struct list_elem* thread_tag;//这个只是后面用于计算使用，计算的是偏差

extern void switch_to(struct task_struct* cur, struct task_struct* next);
//获取当前正在任务的PCB指针
struct task_struct* running_thread_pcb() {
    uint32_t esp;
    asm("mov %%esp,%0" : "=g"(esp));
    /* 取asm整数部分，即pcb起始地址 */
    return (struct task_struct*)(esp & 0xfffff000);

}

    /* 由kernel_thread去执行function(func_arg) */
void kernel_thread(thread_func function, void* func_arg) {
    interrupt_enable();
    function(func_arg);
    return;
}

/* 初始化线程栈thread_stack，将待执行的函数和参数方法到thread_stack中相应的位置 */
void thread_create(struct task_struct* pthread, thread_func function, void* func_arg) {
    /* 先预留中断使用栈的空间，可见thread.h中定义的结构 */
    pthread->self_kstack -= sizeof(struct interrrupt_stack);
    /* 再留出线程栈空间，可见thread.h中定义 */
    pthread->self_kstack -= sizeof(struct thread_stack);
    struct thread_stack* kthread_stack = (struct thread_stack*)pthread->self_kstack;//读取线程栈的起始地址
    kthread_stack->eip = kernel_thread;
    kthread_stack->function = function;
    kthread_stack->func_arg = func_arg;
    kthread_stack->ebp = kthread_stack->ebx = kthread_stack->edi = kthread_stack->esi = 0;
    return ;
}

/* 初始化线程基本信息 */
void init_thread(struct task_struct* pthread, char* name, int prio) {
    memset(pthread, 0, sizeof(*pthread));    //将内核栈初始化为0
    strcpy(pthread->name, name);
    if (pthread == main_thread) {
        /* 由于把main函数也封装成一个线程，并且它一直是运行的，故将其直接设为TASK_RUNNING */
        pthread->status = TASK_RUNNING;
    } else {
        pthread->status = TASK_READY;
    }
    /* self_kstack是线程自己在内核态下使用的栈顶地址 */
    pthread->self_kstack = (uint32_t*)((uint32_t)pthread + PG_SIZE);  // 这里栈定地址为啥是这个呢？
    pthread->priority = prio;
    pthread->ticks = prio;
    pthread->elapsed_ticks = 0;
    pthread->pgdir = NULL;
    pthread->stack_magic = 0x19870916;  // 自定义魔数，线程信息的最边缘，如果栈的数据过多会破坏掉这个魔数
}

/* 创建一个优先级为prio的线程，线程名为name，线程所执行的函数是funciton(func_arg) */
struct task_struct* thread_start(char* name, int prio, thread_func function, void* func_arg) {
    /* pcb都位于内核空间，包括用户进程pcb也是在内核空间 */
    struct task_struct* thread = get_kernel_pages(1);
    // put_int((int)thread);
    // put_char('\n');
    init_thread(thread, name, prio);
    thread_create(thread, function, func_arg);

    ASSERT(!elem_find(&thread_ready_list, &thread->general_tag));//查找是否已经在就绪队列中
    list_append(&thread_ready_list, &thread->general_tag);

    ASSERT(!elem_find(&thread_all_list, &thread->all_list_tag));//查找任物在所有队列中是否已经存在
    list_append(&thread_all_list, &thread->all_list_tag);
    // asm volatile("movl %0,%%esp; pop %%ebp; pop %%ebx; pop %%edi; pop %%esi; ret" ::"g"(thread->self_kstack)
    //              : "memory");
    return thread;
}
/* 将kernel中的main函数完善为主线程 */
static void  make_main_thread(void) {
    /* 因为main线程早已运行，咱们在loader.S中进入内核时的mov esp,0xc009f000,
     * 就是为其预留pcb的，因此pcb地址为0xc009e000，不需要用get_kernel_page另分配一页 */
    main_thread = running_thread_pcb();
    init_thread(main_thread, "main", 31);

    /* main函数是当前线程，当前线程不在thread_ready_list中，
     * 所以只将其加在thead_all_list中 */
    ASSERT(!elem_find(&thread_all_list, &main_thread->all_list_tag));
    put_str("make_main_thread\n");
    list_append(&thread_all_list, &main_thread->all_list_tag);
}

/* 实现任务调度 */
void schedule() {
    ASSERT(interrupt_get_status() == INTERRUPT_OFF);
    struct task_struct* cur = running_thread_pcb();
    if (cur->status == TASK_RUNNING) {
        // 若此线程只是cpu时间片到了，将其加入就绪队列队尾
        ASSERT(!elem_find(&thread_ready_list, &cur->general_tag));
        list_append(&thread_ready_list, &cur->general_tag);
        cur->ticks = cur->priority;
        // 重新将当前进程的ticks重置为priority
        cur->status = TASK_READY;
    } else {
        /* 若此线程需要某事件发生后才能继续上cpu运行，
         * 不需要将其加入队列，因为当前不在就绪队列中 */
    }
    ASSERT(!list_empty(&thread_ready_list));//如果就绪链表不为空
    thread_tag = NULL;  // thread_tag清空
    /* 将thread_ready_list队列中的第一个就绪线程弹出，准备将其调度上cpu */
    thread_tag = list_pop(&thread_ready_list);
    struct task_struct* next = elem2entry(struct task_struct, general_tag, thread_tag);
    next->status = TASK_RUNNING;
    switch_to(cur, next);
}

/**
 * 阻塞当前线程.
 */
void thread_block(enum task_status status) {
    ASSERT(status == TASK_BLOCKED || status == TASK_HANGING || status == TASK_WAITTING);

    interrupt_status old_status = interrupt_disable();

    struct task_struct* cur = running_thread_pcb();
    cur->status = status;
    schedule();

    // 等到当前线程再次被调度时才能执行下面的语句
    // 调度的其它线程无非两种情况:
    // 1. 如果第一次执行，那么在kernel_thread方法中第一件事就是开中断
    // 2. 如果不是第一次执行，那么通过中断返回的方式继续执行，而iret执行也会再次开中断
    interrupt_set_status(old_status);
}

void thread_unblock(struct task_struct* pthread) {
    interrupt_status old_status = interrupt_disable();

    ASSERT(pthread->status == TASK_BLOCKED || pthread->status == TASK_HANGING || pthread->status == TASK_WAITTING);

    if (pthread->status != TASK_READY) {
        ASSERT(!elem_find(&thread_ready_list, &pthread->general_tag));
        list_push(&thread_ready_list, &pthread->general_tag);
        pthread->status = TASK_READY;
    }
    interrupt_set_status(old_status);
}

/* 初始化线程环境 */
void thread_init(void) {
    put_str("thread_init start\n");
    list_init(&thread_ready_list);
    list_init(&thread_all_list);
    /* 将当前main函数创建为线程 */
    make_main_thread();
    put_str("thread_init done\n");
}
/*启用时钟调用函数*/
unsigned int ticks=0;
void schedule_irq(uint8_t vec_nr) {
    struct task_struct* cur_thread = running_thread_pcb();
    // put_str("cao ");
    ASSERT(cur_thread->stack_magic == 0x19870916);  // 检查栈是否溢出
    cur_thread->elapsed_ticks++;  // 记录此线程占用的 cpu 时间
    ticks++;  // 从内核第一次处理时间中断后开始至今的滴哒数，内核态和用户态总共的嘀哒数
    if (cur_thread->ticks == 0) {  // 若进程时间片用完，就开始调度新的进程上 cpu
        schedule();
    }
    else {  // 将当前进程的时间片-1
        cur_thread->ticks--;
    }
    return;
}
