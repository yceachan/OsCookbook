> https://blog.csdn.net/qq_62000508/article/details/149233371

![image-20251224172035630](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/image-20251224172035630.png)

在NAT模式的地址层层转发屎山下，外网访问虚拟机困难的，包括在虚拟机内直接安装CLASH并订阅的方法。

解决方法：

CLASH更新至最新，打开TUN（虚拟网卡代理），和局域网连接

![image-20251224172305634](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/image-20251224172305634.png)

验证

`curl ipinfo.io`

![image-20251224172339692](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/image-20251224172339692.png)