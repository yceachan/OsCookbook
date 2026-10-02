# 将 Ghostty 配置成 Windows Terminal 风格

环境：KDE Plasma 6、Wayland、Ghostty 1.3.1。

## Ghostty

确认字体已安装：

```bash
fc-match 'Hack Nerd Font Mono'
```

编辑 `~/.config/ghostty/config.ghostty`：

```ini
# 常驻集成式 Tab Bar，隐藏独立 Title Bar
gtk-titlebar = true
gtk-titlebar-style = tabs
gtk-tabs-location = top
gtk-wide-tabs = false
gtk-toolbar-style = flat
window-show-tab-bar = always
window-decoration = client

# 默认尺寸：100 列 × 32 行
window-width = 100
window-height = 32

# 外观
theme = Catppuccin Mocha
font-family = Hack Nerd Font Mono

# 自动分屏、关闭当前分屏
keybind = alt+shift+d=new_split:auto
keybind = ctrl+w=close_surface
```

操作：

- `+`：新建 Tab；旁边的小箭头：选择分屏方向。
- `Alt+Shift+D`：按较长边自动分屏。
- `Ctrl+Shift+O` / `Ctrl+Shift+E`：向右 / 向下分屏。
- `Ctrl+W`：关闭聚焦分屏；仅剩一个分屏时关闭该 Tab。
- `Ctrl+Shift+W`：关闭聚焦 Tab；`Alt+F4`：关闭窗口。
- `Ctrl+Shift+,`：重新加载配置。

> Ghostty 目前不能配置 `Alt+左键点击 +`；使用 `+` 旁的分屏菜单或 `Alt+Shift+D` 代替。

## 设为 KDE 默认终端

```bash
kwriteconfig6 --file kdeglobals --group General \
  --key TerminalApplication /usr/bin/ghostty
kwriteconfig6 --file kdeglobals --group General \
  --key TerminalService com.mitchellh.ghostty.desktop
```

## 添加 `wt` 别名

Shell 别名（加入 `~/.profile/alias.bash`，该文件已由 `.zshrc` 加载）：

```bash
alias wt='ghostty'
```

KRunner 不读取 Shell alias。先创建独立启动器 `~/.local/bin/wt`，避免 KRunner 将别名入口与系统 Ghostty 合并：

```sh
#!/bin/sh
exec /usr/bin/ghostty "$@"
```

```bash
chmod 755 ~/.local/bin/wt
```

再创建 `~/.local/share/applications/wt.desktop`：

```ini
[Desktop Entry]
Type=Application
Name=wt
GenericName=Ghostty Terminal
Exec=/home/pi/.local/bin/wt
TryExec=/home/pi/.local/bin/wt
Icon=com.mitchellh.ghostty
Categories=System;TerminalEmulator;
Keywords=wt;ghostty;terminal;console;shell;
Terminal=false
```

刷新 KDE 应用索引：

```bash
kbuildsycoca6 --noincremental
systemctl --user restart plasma-krunner.service
```

之后可在新终端或 KRunner 中输入 `wt` 启动 Ghostty。

## 区分 KRunner 与文件管理器的启动目录

期望行为：

- 从 `Win+R` / KRunner 启动 Ghostty 时，进入用户主目录 `~`。
- 从 Dolphin 的“在此位置打开终端”启动时，进入当前目录。
- 在 Ghostty 内新建 Tab 时，仍继承当前 Tab 的目录。

在 `~/.config/ghostty/config.ghostty` 中加入：

```ini
# 继承启动进程提供的目录，不使用已有 Ghostty 窗口的目录。
working-directory = inherit
window-inherit-working-directory = false
```

KRunner 进程的工作目录是 `~`，Dolphin 会把当前目录设置成终端进程的工作目录。
`window-inherit-working-directory = false` 防止已有 Ghostty 窗口的目录覆盖启动
进程提供的目录。该设置只影响新窗口；新 Tab 是否继承目录由
`tab-inherit-working-directory` 控制，其默认值为 `true`。

KDE 的通用终端任务不会为 Ghostty 添加 `--working-directory` 参数，只会设置
新进程的工作目录。Ghostty 的单实例模式会把新窗口交给已运行的主进程，导致
这个目录丢失。因此需要创建一个仅供 KDE 通用终端任务使用的隐藏启动项
`~/.local/share/applications/ghostty-kde-terminal.desktop`：

```ini
[Desktop Entry]
Version=1.0
Type=Application
Name=Ghostty (KDE terminal launcher)
Comment=Launch Ghostty in the working directory supplied by KDE
TryExec=/usr/bin/ghostty
Exec=/usr/bin/ghostty --gtk-single-instance=false
Icon=com.mitchellh.ghostty
Categories=System;TerminalEmulator;
Terminal=false
NoDisplay=true
StartupNotify=true
StartupWMClass=com.mitchellh.ghostty
```

将它设为 KDE 通用终端任务使用的服务；系统 Ghostty 启动项仍供 KRunner 使用：

```bash
kwriteconfig6 --file kdeglobals --group General \
  --key TerminalApplication /usr/bin/ghostty
kwriteconfig6 --file kdeglobals --group General \
  --key TerminalService ghostty-kde-terminal.desktop
kbuildsycoca6 --noincremental
```

检查配置并让已运行的 Ghostty 重新加载：

```bash
ghostty +validate-config
```

然后在 Ghostty 中按 `Ctrl+Shift+,`，或完全退出后重新启动 Ghostty。
已经运行的 Dolphin 会缓存默认终端服务；关闭所有 Dolphin 窗口后重新打开，
或重新登录 Plasma 会话，才能使用新的隐藏启动项。
