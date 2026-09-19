# ghostty_PD_drawer

面向 KDE Plasma 6 Wayland 的 Ghostty 下拉终端。配置以用户目录安装，不依赖具体 Linux 发行版的包路径。

## 功能

| 快捷键 | 行为 |
| --- | --- |
| `Meta+\`` | 显示或收起下拉终端 |
| `Esc` | 下拉终端聚焦时收起，不影响其他窗口 |
| `Ctrl+b d` | 从 tmux 分离，session 保留供其他终端恢复 |
| `Meta+F` | 新建普通 Ghostty 窗口，并把 drawer tmux session 转移过去 |

下拉终端启动后执行 `tmux new-session -A -s ghostty-pd-drawer`。`Meta+F` 使用 `-D` 接管 session，因此会分离该 session 上的其他客户端。

## 安装

依赖：Ghostty 1.3+、tmux、KDE Plasma 6 Wayland、systemd user manager、Python 3 + PyGObject。

```bash
./install.sh
```

可自定义 tmux session 名：

```bash
GHOSTTY_PD_DRAWER_TMUX_SESSION=my-drawer ./install.sh
```

安装器会验证依赖、备份首次遇到的同名旧文件、安装用户级配置、更新 KWin 规则、启用 controller 服务，并热重载 KWin 脚本。正在运行的旧 drawer 不会被强制关闭；关闭它一次后，再按 `Meta+\`` 即会进入 tmux。

## 支持范围

安装脚本不调用发行版包管理器，可用于采用常规 XDG 目录的 Fedora、Ubuntu、Debian、Arch 等 Linux 系统。窗口管理部分依赖 KWin 6 脚本 API；GNOME、X11 和其他合成器不在此项目的支持范围内。
