函数指针
指向函数的一个指针: 从;()优先级>解引用*
比如定义一个函数指针：
int (*p)(int x,int y);

这个P是一个指针，指向函数的指针；
下面在定义一个具体的函数
int maxValue (int a, int b)
{
    return a > b ? a : b;
}

将p指向maxValue  p=maxValue，或者 p=&maxValue

如何调用函数呢？
p(a,b)即可；

函数指针的用法：
1、函数指针可以作为参数传递
void MyFunction(..., int (*p)(int,int),....)
2、函数指针可以作为返回值
这个不清楚有什么用

