#一些待解决的问题

啥是平坦模型？
在实模式下：由于寄存器只有16位，所以需要采用段地址<<4+偏移地址 实现对内存的访问，这种访问需要将内存分为多个段进行管理，所以成为多段模型
但是在保护模式下：其地址总线是32位，一个段就可以访问所有的内存情况，所以只有一个段，不需要平凡的跨段访问，所有又称为平坦模型