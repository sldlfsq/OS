 ;-------------------- 定义进入loader需要的宏 --------------------------------
 LOADER_BASE_ADDR equ 0x700 ;在里的equ相当于#define，这里定义的是loader的基地址
 LOADER_START_SECTOR equ 0x2 ;这里存储的相当于读如的扇区数目

;-------------------- gdt描述符属性 --------------------------------
;根据寄存器的状态来定义宏，这是在嵌入式领域常用的一个方法

DESC_G_4K equ 1_00000000000000000000000b ;第23位G 表示4K或者1MB位 段界限的单位值 此时为1则为4k
DESC_D_32 equ 1_0000000000000000000000b  ;第22位D/B位 表示地址值用32位EIP寄存器 操作数与指令码32位
DESC_L    equ 0_000000000000000000000b   ;第21位 设置成0表示不设置成64位代码段 忽略
DESC_AVL  equ 0_00000000000000000000b    ;第20位 是软件可用的 操作系统额外提供的 可不设置

DESC_LIMIT_CODE2  equ  1111_0000000000000000b   ;第16-19位 段界限的最后四位 全部初始化为1 因为最大段界限*粒度必须等于0xffffffff
DESC_LIMIT_DATA2  equ  DESC_LIMIT_CODE2         ;相同的值  数据段与代码段段界限相同
DESC_LIMIT_VIDEO2 equ  0000_0000000000000000b	;第16-19位 显存区描述符VIDEO2 书上后面的0少打了一位 这里的全是0为高位 低位即可表示段基址

DESC_P equ 1_000000000000000b	      ;第15位  P present判断段是否存在于内存

DESC_DPL_0  equ  00_0000000000000b    ;第13-14位 这两位更是重量级 Privilege Level 0-3
DESC_DPL_1  equ  01_0000000000000b	  ;0为操作系统 权力最高 3为用户段 用于保护
DESC_DPL_2  equ  10_0000000000000b
DESC_DPL_3  equ  11_0000000000000b

DESC_S_sys  equ  0_000000000000b           ;第12位为0 则表示系统段 为1则表示非系统段
DESC_S_CODE equ  1_000000000000b           ;第12位与type字段结合 判断是否为系统段还是非系统段
DESC_S_DATA equ  1_000000000000b

DESC_TYPE_CODE    equ  1000_00000000b            ;第9-11位表示该段状态 1000 可执行 非一致性 不允许可读 已访问位清0
;x=1 e=0 w=0 a=0
DESC_TYPE_DATA    equ  0010_00000000b            ;第9-11位type段   0010   不可执行 向上扩展的 可写 已访问位清0
;x=0 e=0 w=1 a=0

;设置不同段的属性
;代码段描述符高位4字节初始化 (0x00共8位 <<24 共32位初始化0)
;4KB为单位 Data段32位操作数 初始化的部分段界限 最高权限操作系统代码段 P存在表示 状态
DESC_CODE_HIGH4   equ  (0x00<<24) + DESC_G_4K + DESC_D_32 + \
DESC_L + DESC_AVL + DESC_LIMIT_CODE2 + \
DESC_P + DESC_DPL_0 + DESC_S_CODE + DESC_TYPE_CODE + 0X00

;数据段描述符高位4字节初始化
DESC_DATA_HIGH4   equ  (0x00<<24) + DESC_G_4K + DESC_D_32 + \
DESC_L + DESC_AVL + DESC_LIMIT_DATA2 + \
DESC_P + DESC_DPL_0 + DESC_S_DATA + DESC_TYPE_DATA + 0X00

;显存段描述符高位4字节初始ua
DESC_VIDEO_HIGH4   equ (0x00<<24) + DESC_G_4K + DESC_D_32 + \
DESC_L + DESC_AVL + DESC_LIMIT_VIDEO2 + \
DESC_P + DESC_DPL_0 + DESC_S_DATA + DESC_TYPE_DATA + 0X0b ;整挺好 我看书上写的0x00 结果我自己推算出来这里末尾是B


;-------------------- 选择子属性 --------------------------------
;第0-1位 RPL 特权级比较是否允许访问  第2位TI 0表示GDT 1表示LDT    第3-15位索引值
RPL0    equ 00b
RPL1    equ 01b
RPL2    equ 10b
RPL3    equ 11b
TI_GDT  equ 000b
TI_LDT  equ 100b

;-------------------- loader 和 kernel --------------------------------
PAGE_DIR_TABLE_POS equ 0x100000   ;页表的位置


;---------------- 页表相关属性 --------------
PG_P equ 1b
PG_RW_R equ 00b
PG_RW_W equ 10b
PG_US_S equ 000b
PG_US_U equ 100b

;---------------- 加载到内核相关地址处 --------------
KERNEL_START_SECTOR  equ 0x9
KERNEL_BIN_BASE_ADDR equ 0x70000
KERNEL_ENTER_ADDR    equ 0xc0001500     ;这里是为什么呢？
PT_NULL              equ 0x0            ;这个用于判断是否使用了段头表（elf文件中的表格）
