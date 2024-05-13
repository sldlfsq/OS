/*
 * Author: yanji
 * File: timer.c
 * Description: 修改系统节拍为100hz
 * Date: 2024/5/6
 */
#include "interrupt.h"
#include "io.h"
#include "print.h"
#include "thread.h"

#define IRQ0_FREQUENCY 100
#define INPUT_FREQUENCY 1193180
#define COUNTER0_VALUE INPUT_FREQUENCY / IRQ0_FREQUENCY     //计数器的初值
#define COUNTER0_PORT 0X40          //计数器0的端口号是0x40
#define COUNTER0_NO 0               //计数器0的号码是0，选择那个计数器进行操作，这里是选择计数器0进行操作
#define COUNTER_MODE 2              //这里设置的是计数器0的工作模式，比率模式，这个有自动重装载的功能
#define READ_WRITE_LATCH 3          //控制字的第4-5位是读写方式
#define PIT_COUNTROL_PORT 0x43      //控制字寄存器端口

void frequency_set(uint8_t counter_port, uint8_t counter_no, uint8_t rwl, uint8_t counter_mode,
                   uint16_t counter_value) {
    outb(PIT_COUNTROL_PORT, (uint8_t)(counter_no << 6 | rwl << 4 | counter_mode << 1));
    outb(counter_port, (uint8_t)counter_value);
    outb(counter_port, (uint8_t)counter_value >> 8);
    return;
}

void timer_init(void) {  //将时钟中断为100hz
    put_str("timer_init start!\n");
    frequency_set(COUNTER0_PORT, COUNTER0_NO, READ_WRITE_LATCH, COUNTER_MODE, COUNTER0_VALUE);
    interrupt_register(0x20, schedule_irq, "schedule_irq");
    put_str("timer_init done!\n");
    return;
}
