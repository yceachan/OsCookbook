# PROFILE

[Linux文件 profile、bashrc、bash_profile区别 - 知乎](https://zhuanlan.zhihu.com/p/405174594)

`/etc/profile ` ：全局的登陆脚本

`~/.zshrc`/`~/.bashrc` : ~用户的某shell登陆脚本

shell运行时会加载以上profile，执行其中命令，如设置别名`alias`

导出临时变量 `export`，执行命令`source`

# 环境变量管理

环境变量(environment variables)一般是指在操作系统中用来指定操作系统运行环境的一些参数，是操作系统为了满足不同的应用场景预先在系统内预先设置的一大批全局变量。

**环境变量分类**

* 按生命周期分：

  * 永久的：在环境变量脚本文件中配置，用户每次登录时会自动执行这些脚本，相当于永久生效。

  * 临时的：用户利用export命令，在当前终端下声明环境变量，关闭Shell终端失效。

* 按作用域分：
  * 系统环境变量：公共的，对全部的用户都生效。
  * 用户环境变量：用户私有的、自定义的个性化设置，只对该用户生效。

`export` :创建一组临时的变量，生命周期为本次shell

`export PATH=$PATH:/tmp/bin`



可在其中执行export命令以添加临时的环境变量：

`/etc/environment` :系统环境变量文件

`source <.sh>` 执行一个命令文件，等效于`./<.sh>`

# 链接 ln 

Linux文件系统中，有所谓的链接(link)，我们可以将其视为档案的别名，而链接又可分为两种 : 硬链接(hard link)与软链接(symbolic link)，硬链接的意思是一个档案可以有多个名称，而软链接的方式则是产生一个特殊的档案，该档案的内容是指向另一个档案的位置。硬链接是存在同一个文件系统中，而软链接却可以跨越不同的文件系统。

- 1.硬链接，以文件副本的形式存在。但不占用实际空间。
- 2.软链接，以路径的形式存在。类似于Windows操作系统中的快捷方式

`ln <src> <alias>`

- -n 把符号链接视为一般目录
- -s 创建软链接，而非默认的硬链接

# 权限 chown chgp chmod

⚫ chgrp：改变文件所属用户组
⚫ chown：改变文件所有者
⚫ chmod：改变文件的权限

## chmod 改变文件的权限

文件权限有两种设置方法：数字类型改变权限和符号改变权限。
首先说明各个权限对应的数字：
⚫ r: 4 或 0
⚫ w: 2 或 0
⚫ x: 1 或 0

⚫ 使用 u、g、o 三个字母代表 user、group、others 3 中身份。此外 a 代表all，即所有身份。

e.g:

`chmod u=rwx,go=rx .bashrc` 

`chmod 777 .bashrc`  

`chmod <aguo> <+/-/=> <wrx> .bashrc` 

# vim

**mode**

![image-20250304012402130](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202503040124325.png)

**cousor**

![image-20250304010002297](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202503040100384.png)

**command**

![image-20250304010018189](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202503040100279.png)

![image-20250304010040948](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202503040100079.png)
