# include "sync.h"
# include "interrupt.h"
# include "debug.h"

void semaphore_init(struct semaphore* psem, uint8_t value) {
    psem->value = value;
    list_init(&psem->waiters);
}

void lock_init(struct lock* lock) {
    lock->holder = NULL;
    lock->holder_repeat_num = 0;
    semaphore_init(&lock->semaphore, 1);
}

void semaphore_down(struct semaphore* psem) {
    enum intr_status old_status = intr_disable();

    while (psem->value == 0) {                          //信号量为0，表示资源已经被占用
        struct task_struct* cur = running_thread();     //获取当前线程
        ASSERT(!list_find(&psem->waiters, &cur->general_tag));  //确保当前线程不在资源等待队列中
        list_append(&psem->waiters, &cur->general_tag);     //将当前线程加入资源等待队列
        thread_block(TASK_BLOCKED);                     //阻塞当前线程
    }

    psem->value--;
    ASSERT(psem->value == 0);
    intr_set_status(old_status);
}

void semaphore_up(struct semaphore* psem) {
     enum intr_status old_status = intr_disable();
     ASSERT(psem->value == 0);

     if (!list_empty(&psem->waiters)) {
         struct task_struct* waiter = elem2entry(struct task_struct, general_tag, list_pop(&psem->waiters)); //获取等待线程PCB
         thread_unblock(waiter);     //解除线程阻塞，并且将其加入到就绪队列首部
     }

     psem->value++;
     ASSERT(psem->value == 1);
     intr_set_status(old_status);
}

/**
 * 申请锁.
 */
void lock_acquire(struct lock* plock) {
    struct task_struct* cur = running_thread();
    if (plock->holder != cur) {
        semaphore_down(&plock->semaphore);   //对信号量P操作，申请锁，申请失败则阻塞
        plock->holder = cur;
        ASSERT(plock->holder_repeat_num == 0);
        plock->holder_repeat_num = 1;
    } else {
        plock->holder_repeat_num++;
    }
}

/**
 * 锁释放.
 */
void lock_release(struct lock* plock) {
    ASSERT(plock->holder == running_thread());

    if (plock->holder_repeat_num > 1) {
        plock->holder_repeat_num--;
        return;
    }

    ASSERT(plock->holder_repeat_num == 1);

    plock->holder = NULL;                       //先将锁的持有者置空
    plock->holder_repeat_num = 0;
    semaphore_up(&plock->semaphore);            //对信号量V操作，释放锁
}
