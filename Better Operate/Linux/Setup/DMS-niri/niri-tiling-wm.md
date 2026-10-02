---
title: niri 平铺窗口管理器使用入门
tags: [niri, wayland, tiling-wm, dankmaterialshell]
note_types: Cognition
created: 2026-09-11
updated: 2026-09-11
---

# niri 平铺窗口管理器使用入门

> [!note]
> **Ref:** [niri wiki](https://github.com/YaLTeR/niri/wiki) | 本机配置 `~/.config/niri/config.kdl` 与 `~/.config/niri/dms/*.kdl`（DMS 生成）

把 KDE 换成 niri 之后，最需要重置的不是快捷键，而是**窗口模型**。KDE 里窗口是浮在桌面上的矩形，位置和大小由你拖；niri 里窗口排成一条**无限向右延伸的带子**，屏幕只是这条带子上的一个**视口**。理解了这一句，剩下的快捷键就都只是"把视口往哪边推、把窗口插到哪一列"。


## 1. 三个核心概念

**列（column）**：带子上的一格，宽度默认占屏幕一半（本机 `default-column-width { proportion 0.5 }`，`Mod+R` 在 1/3、1/2、2/3 之间轮换）。列可以有多个：`Mod+H/L` 或 `Mod+方向键` 左右移动视口， 屏幕外的列会滚进来。

**列内堆叠**：一列里可以塞多个窗口，纵向叠着（`Mod+K/J` 切换）。用 `Mod+W` 可以把这列切成 tabbed 显示，只露出当前窗口的整个高度。把窗口塞进相邻列用 `Mod+[` / `Mod+]`，踢出去用 `Mod+.`。

**工作区（workspace）**：垂直排列的一摞"带子"，每个显示器一套，按需增删。`Mod+U/I` 或 `Mod+Page_Up/Down` 上下换工作区，`Mod+1..9` 直接跳。所以 niri 没有"最小化"——把不用的窗口推到别的工作区就是等价操作。

## 2. 先记住这张表：`Mod+Shift+/`

niri 自带快捷键浮层，任何时候按 `Mod+Shift+/` 都会列出当前所有绑定（本机配置里 `hotkey-overlay { skip-at-startup }`，所以开机会自动弹出一次，之后按需调出）。下面按用途整理，`Mod` 即 `Super` 键。

日常启动类：

| 按键 | 作用 |
| :--- | :--- |
| `Mod+T` | 打开终端（ghostty） |
| `Mod+Space` | DMS 应用启动器（spotlight） |
| `Alt+Space` | DMS spotlight 搜索条 |
| `Mod+V` | 剪贴板历史 |
| `Mod+N` / `Mod+Shift+N` | 通知中心 / 记事本 |
| `Mod+,` | DMS 设置 |
| `Super+X` | 电源菜单 |
| `Mod+O` / `Mod+Tab` | Overview（所有工作区缩略图，可拖动窗口） |
| `Mod+M` / `Ctrl+Alt+Delete` | 进程管理器 |

窗口与布局类：

| 按键 | 作用 |
| :--- | :--- |
| `Mod+Q` | 关闭当前窗口 |
| `Mod+F` / `Mod+Shift+F` | 最大化列 / 真全屏 |
| `Mod+Shift+T` | 切换浮动窗口 |
| `Mod+Shift+V` | 在浮动窗口和平铺窗口之间切换焦点 |
| `Mod+W` | 当前列改成 tabbed 显示 |
| `Mod+R` / `Mod+Shift+R` | 轮换预设列宽 / 行高 |
| `Mod+Minus` `Mod+Equal` | 列宽 -10% / +10% |
| `Mod+Shift+Minus` `Mod+Shift+Equal` | 行高 -10% / +10% |
| `Mod+C` / `Mod+Ctrl+C` | 居中当前列 / 居中所有可见列 |
| `Mod+Ctrl+F` | 当前列撑满剩余宽度 |
| `Mod+H J K L` 或方向键 | 焦点：左 / 下 / 上 / 右 |
| `Mod+Shift+H J K L` | 把窗口或列往对应方向移动 |
| `Mod+[` `Mod+]` `Mod+.` | 吞进左列 / 吞进右列 / 踢出该列 |
| `Mod+Home` / `Mod+End` | 跳到第一列 / 最后一列 |
| `Mod+Shift+1..9` | 把当前列移到第 N 个工作区 |
| `Mod+Shift+U` / `Mod+Shift+I` | 把当前工作区整体上移 / 下移 |
| `Mod+P` | 轮换显示器配置（DMS） |
| `Print` / `Ctrl+Print` / `Alt+Print` | 截图：选区 / 全屏 / 当前窗口（DMS） |
| `Mod+Alt+L` | 锁屏 |
| `Mod+Shift+P` | 关闭显示器（DPMS） |
| `Mod+Shift+E` | **退出 niri**（回到登录界面） |

多显示器：`Mod+Ctrl+H/J/K/L` 在显示器间移焦点，加 `Shift` 则把整列搬过去。

鼠标：`Mod+滚轮上下` 换工作区，`Mod+滚轮左右` 换列，`Mod+Ctrl+滚轮` 把列搬走。按住 `Mod` 再用鼠标拖动窗口边缘或标题区域，也能移动 / 调整窗口。

## 3. 什么时候该用浮动窗口

平铺是默认，但对话框、计算器、画中画这类"临时小窗"用平铺反而别扭。niri 的处理方式有两条：

一是写窗口规则，让它自动浮动。本机 `config.kdl` 里已经给 GNOME 系应用、`gnome-calculator`、`blueman-manager`、`xdg-desktop-portal`、firefox 的画中画等设置了 `open-floating true`。想给别的应用加规则，可以按 `Mod+Shift+W` 打开 DMS 的窗口规则面板，也可以自己写：

```kdl
window-rule {
    match app-id=r#"^org\.gnome\.Calculator$"#
    open-floating true
}
```

二是临时用 `Mod+Shift+T` 把当前窗口切成浮动，再按一次切回来。

## 4. 配置文件：三层，改哪一层很重要

`~/.config/niri/config.kdl` 是主配置，**只有这一层该手改**。它末尾 include 了 8 个文件：

```kdl
include optional=true "dms/colors.kdl"
include optional=true "dms/layout.kdl"
include optional=true "dms/alttab.kdl"
include optional=true "dms/binds.kdl"
include optional=true "dms/outputs.kdl"
include optional=true "dms/cursor.kdl"
include optional=true "dms/input.kdl"
```

`~/.config/niri/dms/` 下的文件由 DankMaterialShell 生成（文件头写着 `DO NOT EDIT`），你在 DMS 设置里改主题、改键位时它会被覆盖重写。要加自己的键位、启动项、窗口规则，写进 `config.kdl` 末尾即可，例如：

```kdl
// 开机自启
spawn-at-startup "fcitx5" "-d"

// 自定义键位（Mod 是 Super）
binds {
    Mod+Shift+S { spawn "ghostty" "-e" "btop"; }
}
```

配置是**热重载**的：保存即生效，不需要重启 niri。但本机 `config.kdl` 里有 `config-notification { disable-failed }`，它会关掉"配置解析失败"的弹窗提示——所以改完配置一定要手动验证一次：

```bash
niri validate -c ~/.config/niri/config.kdl
```

## 5. 命令行就是 API：`niri msg`

niri 把几乎所有能力都暴露成 `niri msg`，脚本、DMS、外部程序都靠它。常用几条：

```bash
niri msg outputs                 # 显示器、分辨率、缩放、位置
niri msg workspaces              # 各输出上的工作区状态
niri msg windows                 # 打开的窗口与 app-id
niri msg focused-window          # 当前焦点窗口
niri msg --json workspaces       # 同样的数据，JSON 输出，方便脚本消费
niri msg action focus-column-right
niri msg action spawn -- ghostty
niri msg action do-screen-transition
```

`niri msg action <TAB>` 可以列出全部动作（`close-window`、`toggle-window-floating`、`focus-workspace 3`……），这就是"用命令行点快捷键"。临时改显示器配置也可以不写配置文件：

```bash
niri msg output HDMI-A-1 mode 1920x1080@60 position 1706 0
```

## 6. 从 KDE 过来最容易踩的坑

**`Mod+Shift+E` 会直接退出 niri**，不是关窗口——关窗口是 `Mod+Q`。这两个键挨着的组合建议早点形成肌肉记忆。

**没有任务栏，也没有最小化**。要切回某个窗口，用 `Alt+Tab`（本机 recent-windows 覆盖）、`Mod+O` 的 Overview，或者它在哪个工作区就 `Mod+1..9` 跳过去。

**托盘、时钟、音量、亮度都在 DMS 的 bar 上**，不在 niri 里。音量 / 亮度 / 播放暂停这类多媒体键由 DMS 处理（`XF86Audio*`、`XF86MonBrightness*`）。

**DMS 的窗口规则会和 niri 配置叠加**：DMS 给所有平铺窗口设了 `geometry-corner-radius 12`、`clip-to-geometry true`，主配置又设了 `border { off }`、`focus-ring { width 2 }`，所以边框看起来是圆角细环而不是方框。

**浮动窗口不参与滚动**，它停在视口上；`Mod+Shift+V` 可以在浮动层和平铺层之间切焦点，避免"点不到"。

## 7. 卡住了怎么办

niri 挂掉或键位失效时，先切到 TTY：`Ctrl+Alt+F3`（F2、F4 依次类推），登录后：

```bash
niri msg action quit          # 让当前的 niri 退出，回到登录管理器
journalctl --user -u niri.service -n 100    # 看 niri 的日志
```

配置写坏导致起不来的话，用 `niri validate` 找出错行；实在不行把 `~/.config/niri/config.kdl` 移走，niri 下次启动会用内置默认配置重新生成一份。

显示器位置报 `overlaps an existing output` 之类的警告时，用 `niri msg outputs` 看实际几何，再写 `output "HDMI-A-1" { ... }` 或用 `niri msg output` 调整，别让两块屏的矩形重叠。
