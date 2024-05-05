/***************** 机器模式 *******************
 * b -- 输出寄存器QImode名称，即寄存器中最低8位：[a-d]l
 * w -- 输出寄存器HImode名称，即寄存器中2字节的部分，如[a-d]x
 *
 * HImode
 *    "Half-Integer"模式，表示一个两字节的整数
 * QImode
 *     "Quarter-Integer"模式，表示一个一字节的整数
 * *********************************************************/

#ifndef __LIB_IO_H
#define __LIB_IO_H
#include "stdint.h"

/* 向端口port写入一个字节*/
//将out 指令进行封装
static inline void outb(uint16_t port, uint8_t data) {
    /***************************************************
     * 对端口指定N表示0~255，d表示dx存储端口号，
     * %b0表示对应al,%w1表示对应dx */
    //N表示立即数约束：0-255，d表示寄存器约束，表示dx寄存器
    asm volatile("out %b0,%w1" ::"a"(data), "Nd"(port));
}

/* 将addr处起始的word_cnt个字节写入端口port */
static inline void outsw(uint16_t port, const void* addr, uint32_t word_cnt) {
    /**************************************************
     * +表示此限制既作输入，又作输出
     * outsw是把ds:esi处的16位的内容写入port端口，我们在设置段描述符时，
     * 已经将ds,es,ss段的选择子都设置为相同的值了，此时不用担心数据错乱。*/

    /*这段汇编指令使用了内联汇编语法，它的含义如下：
    cld：该指令设置方向标志位DF（Direction Flag）为0，表示数据传输的方向为递增。这样可以确保数据传输的顺序是从源地址到目的地址。
    rep outsw：这是一个重复指令，在本例中，rep 指示重复执行后面的指令，直到寄存器 CX（计数寄存器）的值达到零。outsw
               是一个输出指令，用于将存储在由 DS:SI 寄存器对应的源内存地址中的一个字（16位）的数据写入到I/O端口。
    "+S"(addr)：+S 表示将寄存器 SI 的值用作输入和输出，同时在执行完指令后更新它，对应于C语言中的变量 addr。
    "+c"(word_cnt)：+c 表示将寄存器 CX 的值用作输入和输出，表示重复执行的次数，对应于C语言中的变量 word_cnt。
    "d"(port)：d 表示将寄存器 DX 的值作为输入传递给指令，表示I/O端口的地址，对应于C语言中的常量 port。
    这段汇编代码的功能是从内存地址 addr 开始，连续从内存中读取16位数据，并将这些数据依次写入到指定的I/O端口 port中，重复操作 word_cnt 次。
    */
    asm volatile("cld;rep outsw" : "+S"(addr), "+c"(word_cnt) : "d"(port));
}

/*将从端口port读入的一个字节返回*/
static inline uint8_t inb(uint16_t port) {
    uint8_t data;
    // in al, dx
    // Nd 表示0-255的立即数
    asm volatile("in %w1,%b0" : "=a"(data) : "Nd"(port));
    return data;
}

/*将从端口port读入的word_cnt个字写入addr*/
static inline void insw(uint16_t port, void* addr, uint32_t word_cnt) {
    /*************************************************
     * insw是将从端口port处读入的16位内容写入es:edi指向的内存，
     * 我们在设置段描述符时，已经将ds,es,ss段的选择子都设置为相同的值了，
     * 此时不用担心数据错乱。*/
    /*
    cld：该指令设置方向标志位DF（Direction Flag）为0，表示数据传输的方向为递增。这样可以确保数据传输的顺序是从源地址到目的地址。
    rep insw：这是一个重复指令，在本例中，rep 指示重复执行后面的指令，直到寄存器 CX（计数寄存器）的值达到零。insw
              是一个输入指令，用于从I/O端口读取一个字（16位）的数据，并将其存储到由 ES:DI 寄存器对应的目的内存地址中。
    "+D"(addr)：+D 表示将寄存器 DI 的值用作输入和输出，同时在执行完指令后更新它，对应于C语言中的变量 addr。
    "+c"(word_cnt)：+c 表示将寄存器 CX 的值用作输入和输出，表示重复执行的次数，对应于C语言中的变量 word_cnt。
    "d"(port)：d 表示将寄存器 DX 的值作为输入传递给指令，表示I/O端口的地址，对应于C语言中的常量 port。
    "memory"：这是一个Clobber List（破坏项），表明内联汇编代码可能会改变内存中的数据，需要告知编译器进行必要的处理。
    */
    asm volatile("cld;rep insw" : "+D"(addr), "+c"(word_cnt) : "d"(port) : "memory");
}

#endif
