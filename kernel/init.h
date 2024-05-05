#ifndef __KERNEL_INIT_H
#define __KERNEL_INIT_H
#include "stdint.h"
/*
    空指针的用处：
    1、表明该变量是地址
    2、可以用于类型强转，面向对象编成可以使用
*/
void init_all(void);
#endif
