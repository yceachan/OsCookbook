apt（Advanced Packaging Tool）是一个在 Debian 和 Ubuntu 中的 Shell 前端软件包管理器。

apt 命令提供了查找、安装、升级、删除某一个、一组甚至全部软件包的命令，而且命令简洁而又好记。

# 软件源

APT 需要指定一个“软件源（仓库）列表”：文件 `/etc/apt/sources.list` 会列出发布 Debian 软件包的不同仓库。接下来 APT 会从每一个软件源导入所发布的软件包列表。

file `/etc/apt/sources.list`

```
deb http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted
deb-src http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted
```

| 源类型   | 配置项  |
| -------- | ------- |
| 二进制包 | deb     |
| 源码包   | deb-src |

软件包维护状态

对于这四种状态的软件包，在源链接里会分到对应四个子目录(加上没状态的共计五个)

| 序号 | 状态     | 说明     | 代号      |
| ---- | -------- | -------- | --------- |
| 1    | 不维护   | 过期功能 | backports |
| 2    | 后期维护 | 安全     | security  |
| 3    | 持续维护 | 更新中   | updates   |
| 4    | 持续更新 | 预发布   | proposed  |

软件包支撑级别

| 序号 | 代号       | 说明     | 支撑级别                       |
| ---- | ---------- | -------- | ------------------------------ |
| 1    | main       | 核心包   | 官方提供支撑和补丁             |
| 2    | restricted | 标准包   | 官方一定程度上提供支撑和补丁   |
| 3    | universe   | 扩展包   | 官方不提供支撑和补丁，社区提供 |
| 4    | multiverse | 自定义包 | 不提供支撑和补丁               |

软件包获取方式

- `apt-get install`: 下载二进制软件包并直接安装
- `apt-get download`: 仅下载二进制软件包(可以传到其他服务器用于离线安装)
- `apt-get source`: 下载源码包(可以修改源码，往往用于自定义安装路径)

## 换源国内镜像站





# 软件包公钥apt-key

`apt-key` **是一个用于管理APT用来验证软件包的密钥的工具。它与 工具密切相关，后者将使用钥匙服务器的外部存储库添加到 APT 安装的可信来源列表中。**

apt-key在ubuntu中因安全性问题逐渐被废弃，替代工具为``gpg`

* 带秘钥认证的三方软件包下载流程：

1. 添加公钥

   1. 使用curl传输工具获得公钥明文

      `curl -fsSL <url> | <pipe rhs>` 

      * -f --form制定url
      * -s --silent 无进度条提示
      * -S --show-error 显示错误
      * -L --link 跟随目标url的重定向

      2. 使用gpg工具添加公钥

         `<pub text>| sudo gpg --dearmor -o /usr/share/keyrings/<pub.gpg>`

         * `/usr/share/keyrings` gpg公钥目录

2. 添加仓库deb （二进制）/debsrc（源码）

   编辑`/etc/apt/source.list`文件，键入新仓库

   `deb [arch=amd64 signed-by=<.gpg>] <url of source> <stable> <main>`



# 软件包

`dpkg` :软件包管理工具，可以安装deb包，apt在其上，增添软件源的功能，处理以来能力更加

