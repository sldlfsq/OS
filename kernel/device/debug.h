#ifndef __KERNEL_DEBUG_H
#define __KERNEL_DEBUG_H
void panic_spin(char* filename, int line, const char* func, const char* condition);

/**************************** __VA_ARGS__ *******************************
 * __VA_ARGS__是预处理器所支持的专用标识符。
 * 代表所有与省略号相对应的参数。
 * "..."表示定义的宏，其参数可变。*/
//__VA_ARGS__与...相对应，说明该函数的参数至少有一个，且最后一个参数是可变的
//__FILE__, __LINE__, __func__
#define PANIC(...) panic_spin(__FILE__, __LINE__, __func__, __VA_ARGS__)

//当不需要debug的时候，将ASSERT宏定义为空，这样在编译的时候就不会编译ASSERT了
//也就是在gcc命令中加入-D NDEBUG
#ifdef NDEBUG
    #define ASSERT(CONDITION) ((void)0)
#else
    #define ASSERT(CONDITION)\
    if (CONDITION) {}     \
    else {PANIC(#CONDITION); /* 符号#让编译器将宏的参数转化为字符串字面量 */}
#endif /* __NDEBUG */

#endif /* __KERNEL_DEBUG_H */
