# 解决sudo执行相应时间过长

这个指令是由于在执行sudo 指令时， 当前host主机未能被正确解析导致的

solve：

```
sudo vim /etc/hosts
#找到127.0.0.1 <loaclhost> 追加新行
127.0.0.1 myhostname #当前计算机名称
```

![image-20251221233846110](C:\Users\yceachan\AppData\Roaming\Typora\typora-user-images\image-20251221233846110.png)