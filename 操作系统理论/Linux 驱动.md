* Linux Overview

![image-20250307044541997](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202503070445186.png)

* 驱动 OVerview

![image-20250307050555748](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202503070505811.png)

**1.字符设备驱动：**

按照字节流访问，只能顺序访问，不能无序访问。会产生设备文件节点/dev/xxx设备节点，应用层进程访问字符设备时，需要能过vfs与之交互，open read write... 无缓冲。

**2.块设备驱动：**

按照块来访问（块= 512byte）可以顺序访问，也可以无序访问，产生设备节点，应用层进程能过vfs文件系统进行交互。有缓冲。

**3.网络设备：通过网络进行数据收发的设备 网卡**

不产生vfs中产生设备节点，通过socket节点进行交互。

# app 文件IO

文件IO有两套接口，标准IO 与 系统IO 

标准IO （`fopen、fread、fwrite`）等，开辟用户buffer，底层调用系统IO(`open read write`)

![image-20250307063508204](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202503070635258.png)





# 字符设备

* app api : `open read write`

驱动程序提供如上api函数给app调用。

![image-20250307062550195](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202503070625273.png)