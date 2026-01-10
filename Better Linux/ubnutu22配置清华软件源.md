# Ubuntu 22.04 LTS (Jammy Jellyfish) 清华镜像站 APT 配置

以下是适用于 Ubuntu 22.04.x LTS (代号 `jammy`) 版本的 `sources.list` 配置内容，可直接复制粘贴到 `/etc/apt/sources.list` 文件中，以将 APT 软件源切换到清华大学镜像站。

```
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse

deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
# deb-src http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse

# 预发布软件源，不建议启用
# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-proposed main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-proposed main restricted universe multiverse
```

### 使用说明

1.  **备份原文件**: `sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak`
2.  **编辑文件**: `sudo nano /etc/apt/sources.list` (或使用您喜欢的编辑器)
3.  **粘贴内容**: 清空原文件内容，然后将上方代码块中的内容完整粘贴进去。
4.  **保存退出**: (在 nano 中按 `Ctrl + X`, `Y`, `Enter`)
5.  **更新软件包列表**: `sudo apt update`
