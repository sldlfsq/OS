/*
 * Author: yanji
 * File: string.c
 * Description: 实现字符串操作的函数
 * Date: 2024/5/6
 */
#include "string.h"
#include "debug.h"
#include "global.h"

//将起始地址为dst_的size个字节置为value
void memset(void* dst_,uint8_t value,uint32_t size)
{
    ASSERT(dst_ != NULL);
    uint8_t* dst = (uint8_t*) dst_;
    while((size--) > 0)
        *(dst++) = value;
    return;
}

void memcpy(void* dst_,const void* src_,uint32_t size)
{
    ASSERT(dst_ != NULL && src_ != NULL);
    uint8_t* dst = dst_;
    const uint8_t* src = src_;
    //size--和--size的值
    //这种的话应该从左往右读，比如size--，先size，然后再用size--的值
    while((size--) > 0)
        *(dst++) = *(src++);
    return;
}

//比较两个字符串是否相同
int memcmp(const void* a_,const void* b_, uint32_t size)
{
    const char* a = a_;
    const char* b = b_;
    ASSERT(a != NULL || b != NULL);
    while((size--) > 0)
    {
        if(*a != *b)    return (*a > *b) ? 1 : -1;
       ++a,++b;
    }
    return 0;
}

char* strcpy(char* dsc_,const char* src_)
{
    ASSERT(dsc_ != NULL && src_ != NULL);
    char* dsc = dsc_;
    //这里的*src_是为了判断src_是否为空，是先赋值在进行判断
    //当*src = ‘\0’时，赋值结束
    while((*(dsc_++) = *(src_++) ));
    return dsc;
}

uint32_t strlen(const char* str)
{
    ASSERT(str != NULL);
    const char* ptr = str;
    while(*(ptr++));
    return (ptr - str - 1);  //这里是由于当ptr指向'\0'时，ptr还会加1，所以要减去1
}

int8_t strcmp(const char* a,const char* b)
{
    ASSERT(a != NULL && b != NULL);
    while(*a && *a == *b)
    {
        a++,b++;
    }
    return (*a < *b) ? -1 : (*a > *b) ;
}

char* strchr(const char* str,const char ch)
{
    ASSERT(str != NULL);
    while(*str)
    {
        if(*str == ch)    return (char*)str;
        ++str;
    }
    return NULL;
}

char* strrchr(const char* str,const uint8_t ch)
{
    ASSERT(str != NULL);
    char* last_chrptr = NULL;
    while(*str != 0)
    {
        if(ch == *str)    last_chrptr = (char*)str;
        str++;
    }
    return last_chrptr;
}

char* strcat(char* dsc_,const char* src_)
{
    ASSERT(dsc_ != NULL && src_ != NULL);
    char* str = dsc_;
    while(*(str++));
    str--;
    while((*(str++) = *(src_++)) != 0);
    return dsc_;
}

uint32_t strchrs(const char* str,uint8_t ch)
{
    ASSERT(str != NULL);
    uint32_t ch_cnt = 0;
    while(*str)
    {
        if(*str == ch) ++ch_cnt;
        ++str;
    }
    return ch_cnt;
}
