/*
 * Author: yanji
 * File: interrput.c
 * Description: create interrupt descriptor table and interrupt service routine
 * Date: 2024/5/4
 */
#include "global.h"
#include "interrupt.h"
#include "io.h"
#include "stdint.h"

#define PIC_M_CTRL 0x20  // 主片的控制端口是0x20
#define PIC_M_DATA 0x21  // 主片的数据端口是0x21
#define PIC_S_CTRL 0xa0  // 从片的控制端口是0xa0
#define PIC_S_DATA 0xa1  // 从片的数据端口是0xa1

#define IDT_DESC_CNT 33  // 目前总共支持的中断数，这里定义了  0-0x20 共33个中断

/*中断门描述符结构体*/
struct gate_desc {
    uint16_t func_offset_low_word;
    uint16_t selector;
    uint8_t dcount;     // 此项为双字计数字段，是门描述符的第4字节，固定值
    uint8_t attribute;  // 属性值
    uint16_t func_offset_high_word;
};

// 静态函数声明，非必须
static void make_idt_desc(struct gate_desc* p_gdesc, uint8_t attr, intr_handler function);
static struct gate_desc idt[IDT_DESC_CNT];  // IDT是中断描述符表，本质上就是个中断描述符数组

extern intr_handler intr_entry_table[IDT_DESC_CNT];  // 声明引用定义在kernel.S中的中断处理函数入口数组,但是这个返回值是什么意思呢？

/* 初始化可编程中断控制器8259A */
static void pic_init(void) {
    /*初始化主片*/
    outb(PIC_M_CTRL, 0x11);     // ICW1: 边沿触发,级联 8259, 需要 ICW4
    outb(PIC_M_DATA, 0x20);     // ICW2: 起始中断向量号为 0x20——0x27
    outb(PIC_M_DATA, 0x04);     // ICW3: IR2 接从片
    outb(PIC_M_DATA, 0x01);     // ICW4: 8086 模式，正常 EOI

    /*初始化从片*/
    outb(PIC_S_CTRL, 0x11);     // ICW1: 边沿触发,级联 8259, 需要 ICW4
    outb(PIC_S_DATA, 0x28);     // ICW2: 起始中断向量号为 0x28-0x2f
    outb(PIC_S_DATA, 0x02);     // ICW3: 设置从片连接到主片的 IR2 引脚
    outb(PIC_S_DATA, 0x01);     // ICW4: 8086 模式，正常 EOI

    /*打开主片上IR0，也就是目前只接受时钟产生的中断*/
    outb(PIC_M_DATA, 0xfe);    // 0xfe = 1111 1110，只打开时钟中断
    outb(PIC_S_DATA, 0xff);    // 屏蔽掉从片上外设的所有中断

    put_str("pic_init done\n");
}

/*创建中断门描述符*/
static void make_idt_desc(struct gate_desc* p_gdesc, uint8_t attr, intr_handler function) {
    p_gdesc->func_offset_low_word = (uint32_t)function & 0x0000ffff;    //将kernel.S中的中断处理函数的地址赋值给func_offset_low_word
    p_gdesc->selector = SELECTOR_K_CODE;  // 中断后进入内核代码
    p_gdesc->dcount = 0;
    p_gdesc->attribute = attr;            //设置中断门描述符的属性
    p_gdesc->func_offset_high_word = ((uint32_t)function & 0xffff0000) >> 16;
}

/*初始化中断描述符表*/
static void idt_desc_init(void) {
    int i;
    for (i = 0; i < IDT_DESC_CNT; ++i) {
        make_idt_desc(&idt[i], IDT_DESC_ATTR_DPL0, intr_entry_table[i]);
    }
    put_str("idt_desc_init done\n");
}

/*完成有关中断的所有初始化工作*/
void idt_init() {
    put_str("idt_init start\n");
    idt_desc_init();  // 初始化中断描述符表
    pic_init();  // 初始化PIC(8259A)

    /*加载idt*/
    // sizeof(idt) - 1 这个是中断描述符的大小，(uint64_t)(uint32_t)idt << 16 这个是idt的起始地址
    uint64_t idt_operand = ((sizeof(idt) - 1) | ((uint64_t)(uint32_t)idt << 16));
    asm volatile("lidt %0" ::"m"(idt_operand));
    put_str("idt_init done\n");
}
