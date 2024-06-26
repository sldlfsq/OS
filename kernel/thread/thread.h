#ifndef __THREAD_THREAD_H
#define __THREAD_THREAD_H
#include "stdint.h"
#include "list.h"
/* 自定义通用函数类型，它将在很多线程程序中作为参数类型 */
typedef void (*thread_func)(void*);

/* 进程或线程状态 */
enum task_status {
    TASK_RUNNING,  // 运行态
    TASK_READY,  // 就绪态
    TASK_BLOCKED,  // 阻塞态
    TASK_WAITTING,
    TASK_HANGING,
    TASK_DIED
};

/***************** 中断栈intr_stack ******************
 * 此结构用于中断发生时保护程序（线程或进程）的上下文环境
 * 进程或线程被外部中断或软中断打断时，会按照此结构压入上下文
 * 寄存器，intr_exit中的出栈操作是此结构的逆操作
 * 此栈在线程自己的内核栈中的位置固定，所在页的最顶端
 *****************************************************/
struct interrrupt_stack {
    uint32_t vec_no;  // kenrel.S宏VECTOR中push %1压入的中断号
    uint32_t edi;
    uint32_t esi;
    uint32_t ebp;
    uint32_t esp_dummy;  // 虽然pushad会压入esp，但esp是不断变化的，所以会被popad忽略
    uint32_t ebx;
    uint32_t edx;
    uint32_t ecx;
    uint32_t eax;
    uint32_t gs;
    uint32_t fs;
    uint32_t es;
    uint32_t ds;

    /* 以下由cpu从低特权级进入高特权级时压入 */
    uint32_t err_code;  // error_code会被压入在eip之后
    void (*eip)(void);
    uint32_t cs;
    uint32_t eflags;
    void* esp;
    uint32_t ss;
};

/*****************线程栈thread_stack****************
 * 线程自己的栈，用于存储线程中待执行的函数
 * 此结构在线程自己的内核栈中位置不固定，
 * 仅用在switch_to时保存线程环境。
 * 实际位置取决于实际运行情况。
 *************************************************/
struct thread_stack {
    uint32_t ebp;
    uint32_t ebx;
    uint32_t edi;
    uint32_t esi;

    /* 线程第一次执行时，eip指向待调用的函数kernel_thread
     * 其它时候，eip是指向switch_to的返回地址 */
    void (*eip)(thread_func func, void* func_arg);

    /****** 以下仅供第一次被调度上cpu时使用 ******/

    /* 参数unused_ret只为占位置充数为返回地址 */
    //这里是一个难点，为什么需要加一个占位的呢？
    //这里是通过ret调用的函数，所以需要一个返回地址，这个地址是在调用函数的时候压入的
    void (*unused_retaddr);
    thread_func function;  // 由kernel_thread所调用的函数名
    void* func_arg;  // 由kernel_thread所调用的函数所需的参数
};

/* 进程或线程的pcb，程序控制块 */
// struct task_struct {
//     uint32_t* self_kstack;  // 各内核线程都有自己的内核栈
//     enum task_status status;
//     uint8_t priority;  // 线程优先级
//     char name[16];

//     uint32_t ticks;
//     //CPU运行的滴答数，用于时间片轮转调度
//     uint32_t elapsed_ticks;
//     //维护任务就绪链表的节点
//     struct list_elem general_tag;
//     //记录就绪链表的头节点
//     struct list_elem all_list_tag;

//     uint32_t* pgdir;  // 进程自己页表的虚拟地址
//     uint32_t stack_magic;  // 栈的边界标记，用于检测栈的溢出
// };

/* 进程或线程的pcb，程序控制块 */
struct task_struct {
    uint32_t* self_kstack;  // 各内核线程都有自己的内核栈
    enum task_status status;
    char name[16];
    uint8_t priority;  // 线程优先级

    uint32_t ticks;
    //CPU运行的滴答数，用于时间片轮转调度
    uint32_t elapsed_ticks;


    //维护任务就绪链表的节点
    struct list_elem general_tag;
    //记录就绪链表的头节点
    struct list_elem all_list_tag;

    uint32_t* pgdir;  // 进程自己页表的虚拟地址
    uint32_t stack_magic;  // 栈的边界标记，用于检测栈的溢出
};

void kernel_thread(thread_func function, void* func_arg);
void thread_create(struct task_struct* pthread, thread_func function, void* func_arg);
void init_thread(struct task_struct* pthread, char* name, int prio);
struct task_struct* thread_start(char* name, int prio, thread_func function, void* func_arg);
struct task_struct* running_thread_pcb(void);
void schedule(void);
void schedule_irq(uint8_t vec_nr);
void thread_init(void);

void thread_block(enum task_status status);
void thread_unblock(struct task_struct* pthread);
#endif
