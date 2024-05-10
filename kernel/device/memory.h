#ifndef __KERNEL_MEMORY_H
#define __KERNEL_MEMORY_H

#include "stdint.h"
#include "bitmap.h"

struct virtual_addr {
    struct bitmap vaddr_bitmap;  // 虚拟地址用到的位图结构
    uint32_t vaddr_start;  // 虚拟地址起始地址
};

enum pool_flags {
    PF_KERNEL = 1,  // 内核内存池
    PF_USER = 2  // 用户内存池
};

//设置页表相关属性
#define PG_P_1 0  // PG_P_1表示该页是否存在
#define PG_P_0 1  // 0表示不存在
#define PG_RW_W 1   // R/W 属性位， 1表示可读写，0表示只读
#define PG_RW_R 0
#define PG_US_U 0   // U/S 属性位，0表示用户态不可访问该页
#define PG_US_S 1   // 1表示用户态可以访问

void mem_pool_init(uint32_t all_mem);
// void* malloc_page(enum pool_flags pf, uint32_t pg_cnt);
void* get_kernel_pages(uint32_t pg_cnt); //直接调用这个函数就行了


#endif
