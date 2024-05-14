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
#include "thread.h"
#include "print.h"

/*******关于芯片寄存器的定义*********/
#define PIC_M_CTRL 0x20  // 主片的控制端口是0x20
#define PIC_M_DATA 0x21  // 主片的数据端口是0x21
#define PIC_S_CTRL 0xa0  // 从片的控制端口是0xa0
#define PIC_S_DATA 0xa1  // 从片的数据端口是0xa1

#define IDT_DESC_CNT 0x21  // 目前总共支持的中断数，这里定义了  0-0x20 共33个中断，0x20为时钟中断

#define EFLAGS_IF 0x00000200  // eflags寄存器中的if位为1
//=g 是通用约束，编译器可以自由选择合适的方式来处理存储操作
#define GET_EFLAGS(EFLAG_VAR) asm volatile("pushfl; popl %0" : "=g"(EFLAG_VAR))  // 获取eflags寄存器的值
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

//第一步：初始化中断控制芯片
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
    outb(PIC_M_DATA, 0xfe);    // 0xfe = 1111 1110，只打开时钟中断，中断号为0x20
    outb(PIC_S_DATA, 0xff);    // 屏蔽掉从片上外设的所有中断

    put_str("pic_init done\n");
}

// 第二步：创建中断门描述符并且初始化中断描述符表
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

// 第三步：创建中断服务程序数组，并且初始化默认的中断处理程序
interrupt_handler interrupt_handler_table[IDT_DESC_CNT];  // 中断处理函数数组
char* interrput_name[IDT_DESC_CNT];  // 中断名称数组
// 默认的中断处理函数
void default_handler(uint8_t vec_nr) {

    if (vec_nr == 0x27 || vec_nr == 0x2f) {  // 0x2f是从片8259A上的最后一个irq引脚，保留
        return;  // IRQ7和IRQ15会产生伪中断(spurious interrupt),无须处理。
    }

    interrupt_disable();  // 关中断
    /* 将光标置为0，从屏幕左上角清出一片打印异常信息的区域，方便阅读 */
    set_cursor(0);
    int cursor_pos = 0;
    while (cursor_pos < 320) {
        put_char(' ');
        ++cursor_pos;
    }

    set_cursor(0);  // 重置光标为屏幕左上角
    put_str("!!!!!     excetion message begin     !!!!!\n");
    set_cursor(88);
    // put_str("int vector: 0x");
    put_str(interrput_name[vec_nr]);
    if (vec_nr == 14) {  // 若为page_fault，将缺失的地址打印出来并悬停
        int page_fault_vaddr = 0;
        asm("movl %%cr2,%0" : "=r"(page_fault_vaddr));  // cr2是存放page_fault的地址
        put_str("\npage fault addr is ");
        put_int(page_fault_vaddr);
    }
    put_str("\n!!!!!     excetion message end     !!!!!");
    // 能进入中断处理程序就表示已经处在关中断情况下
    // 不会出现调度进程的情况。故下面的死循环不会再被中断
    while (1);
}
// 初始化默认的中断处理函数
void init_default_handler() {
    int i;
    for (i = 0; i < IDT_DESC_CNT; ++i) {
        interrupt_handler_table[i] = default_handler;
        interrput_name[i] = "unknown name";
    }
    interrput_name[0] = "#DE Divide Error";
    interrput_name[1] = "#DB Debug Exception";
    interrput_name[2] = "NMI Interrupt";
    interrput_name[3] = "#BP Breakpoint Exception";
    interrput_name[4] = "#OF Overflow Exception";
    interrput_name[5] = "#BR BOUND Range Exceeded Exception";
    interrput_name[6] = "#UD Invalid Opcode Exception";
    interrput_name[7] = "#NM Device Not Available Exception";
    interrput_name[8] = "#DF Double Fault Exception";
    interrput_name[9] = "Coprocessor Segment Overrun";
    interrput_name[10] = "#TS Invalid TSS Exception";
    interrput_name[11] = "#NP Segment Not Present";
    interrput_name[12] = "#SS Stack Fault Exception";
    interrput_name[13] = "#GP General Protection Exception";
    interrput_name[14] = "#PF Page-Fault Exception";
    // intr_name[15] 第15项是intel保留项，未使用
    interrput_name[16] = "#MF x87 FPU Floating-Point Error";
    interrput_name[17] = "#AC Alignment Check Exception";
    interrput_name[18] = "#MC Machine-Check Exception";
    interrput_name[19] = "#XF SIMD Floating-Point Exception";
}
// 注册中断处理函数
void interrupt_register(uint8_t vec_nr, interrupt_handler function, char* name) {
    interrupt_handler_table[vec_nr] = function;
    interrput_name[vec_nr] = name;
}

//第四步：完成中断状态相关的函数

/* 获取当前中断状态 */
interrupt_status interrupt_get_status() {
    uint32_t eflags = 0;
    GET_EFLAGS(eflags);
    return (EFLAGS_IF & eflags) ? INTERRUPT_ON : INTERRUPT_OFF;
}

/* 使能中断 */
interrupt_status interrupt_enable() {
    interrupt_status old_status;
    if (INTERRUPT_ON == interrupt_get_status()) {
        old_status = INTERRUPT_ON;
        return old_status;
    } else {
        old_status = INTERRUPT_OFF;
        asm volatile("sti");  // 开中断，sti指令将IF位置1
        return old_status;
    }
}

/* 关中断并返回关中断前的状态 */
interrupt_status interrupt_disable() {
    interrupt_status old_status;
    if (INTERRUPT_ON == interrupt_get_status()) {
        old_status = INTERRUPT_ON;
        asm volatile("cli");//刷新内存的数据，它强制编译器在 CLI 指令执行前刷新内存中的数据，防止编译器对 CLI 指令进行优化或重排序。
        return old_status;
    } else {
        old_status = INTERRUPT_OFF;
        return old_status;
    }
}

/* 将中断状态设置为status */
//0是关中断
//1是开中断
interrupt_status interrupt_set_status(interrupt_status status) {
    return status & INTERRUPT_ON ? interrupt_enable() : interrupt_disable();
}

/*完成有关中断的所有初始化工作*/
void idt_init() {
    put_str("idt_init start\n");
    idt_desc_init();  // 初始化中断描述符表
    pic_init();  // 初始化PIC(8259A)
    init_default_handler();  // 初始化默认的中断处理函数
    /*加载idt*/
    // sizeof(idt) - 1 这个是中断描述符的大小，(uint64_t)(uint32_t)idt << 16 这个是idt的起始地址
    uint64_t idt_operand = ((sizeof(idt) - 1) | ((uint64_t)(uint32_t)idt << 16));
    asm volatile("lidt %0" ::"m"(idt_operand));
    // interrupt_disable();
    put_str("idt_init done\n");
}
