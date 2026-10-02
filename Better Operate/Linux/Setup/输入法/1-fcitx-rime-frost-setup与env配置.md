# Fedora KDE Plasma 6：Fcitx5 + Rime 白霜安装与环境配置

本文记录一套在 Fedora 44、KDE Plasma 6、Wayland 会话中验证过的配置。目标是：KDE 原生程序正常使用 Fcitx5，Rime 使用白霜方案，同时不给所有程序强塞互相冲突的输入法环境变量。

## 1. 组件关系

- Fcitx5：输入法框架，负责连接 KDE、GTK、Qt、X11/Wayland 应用。
- fcitx5-rime：Fcitx5 与 Rime 引擎之间的适配层。
- Rime Frost（白霜）：Rime 的方案、词库和 Lua 扩展。
- `librime-lua`、`librime-octagram`：白霜 Lua 功能和语言模型所需插件。

## 2. 安装 Fedora 软件包

```bash
sudo dnf install \
  fcitx5 fcitx5-rime fcitx5-gtk fcitx5-qt \
  fcitx5-configtool kcm-fcitx5 \
  librime-lua librime-octagram git
```

本机验证版本：

```text
fcitx5            5.1.21
fcitx5-rime       5.1.14
librime           1.16.1
fcitx5-qt         5.1.14
fcitx5-gtk        5.1.7
```

## 3. 安装白霜

Fcitx5-Rime 的 Linux 用户目录是：

```text
~/.local/share/fcitx5/rime
```

首次安装前，先确认该目录没有需要保留的个人词库或配置。然后执行：

```bash
mkdir -p ~/.local/share/fcitx5
git clone --depth 1 https://github.com/gaboolic/rime-frost.git \
  ~/.local/share/fcitx5/rime
```

已经通过 Git 安装后，更新只需：

```bash
git -C ~/.local/share/fcitx5/rime pull --ff-only
```

个人修改应放在 `*.custom.yaml`，不要直接编辑白霜仓库里的 `default.yaml` 或 `*.schema.yaml`，否则后续更新容易产生冲突。本机的 Shift 定制位于：

```text
~/.local/share/fcitx5/rime/default.custom.yaml
```

## 4. 在 KDE 中启用

打开“系统设置 → 键盘 → 虚拟键盘/输入法”，选择 Fcitx5。再打开 Fcitx5 配置，将“中州韵（Rime）”加入当前输入法组。

本机只保留一个 Rime 输入法项，默认输入法也是 `rime`。这样中文/英文由 Rime 内部的 `ascii_mode` 管理，不再通过 `keyboard-us` 与 Rime 来回切换。

## 5. Plasma Wayland 的环境变量

本机只在登录会话中保留 X11/XWayland 所需的 `XMODIFIERS`：

文件 `~/.config/environment.d/90-fcitx5.conf`：

```ini
XMODIFIERS=@im=fcitx
```

修改后需要注销并重新登录。不要在 Plasma Wayland 会话里全局强制设置下面两项：

```text
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
```

Qt 6/Wayland、GTK/Wayland 和 XWayland 的输入路径不同，全局强制变量可能使部分 Chromium/Electron 程序走到不稳定或重复的输入路径。确实需要特殊处理的应用，应在它自己的 `.desktop` 启动项里单独设置；ChatGPT/Codex 的处理见第三篇笔记。

## 6. 重新部署与验证

修改 Rime 配置后，从 Fcitx5 托盘菜单选择“重新部署”。也可以重载 Rime 插件：

```bash
busctl --user call org.fcitx.Fcitx5 /controller \
  org.fcitx.Fcitx.Controller1 ReloadAddonConfig s rime
```

检查 Fcitx5 是否运行：

```bash
fcitx5-remote
fcitx5-diagnose
```

检查当前方案：

```bash
busctl --user call org.fcitx.Fcitx5 /rime \
  org.fcitx.Fcitx.Rime1 GetCurrentSchema
```

预期方案为 `rime_frost`。若刚部署完成仍未出现，重新选择一次“白霜拼音”，或完全退出并重启 Fcitx5。

## 7. 备份重点

至少备份以下内容：

```text
~/.local/share/fcitx5/rime/*.custom.yaml
~/.local/share/fcitx5/rime/*.userdb/
~/.config/fcitx5/config
~/.config/fcitx5/profile
~/.config/environment.d/90-fcitx5.conf
```

## 参考

- [fcitx5-rime](https://github.com/fcitx/fcitx5-rime)
- [Rime Frost / 白霜拼音](https://github.com/gaboolic/rime-frost)
- [Fcitx5 官方 Wayland 说明](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland)
- [Fedora KDE + Fcitx5 参考文章](https://jishuzhan.net/article/1951523354925641730)
