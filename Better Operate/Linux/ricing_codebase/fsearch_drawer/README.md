# FSearch drawer

KDE Plasma 6 Wayland 下的 FSearch 常驻窗口。本机原型保留原来的任务栏 pin、图标和应用入口，登录后预加载 FSearch 并隐藏窗口。显示与隐藏复用同一个进程和窗口，保留搜索内容；数据库和索引目录沿用现有配置。

## 使用

| 入口 | 行为 |
| --- | --- |
| `Ctrl+Shift+W` | 隐藏时唤起；FSearch 已聚焦时隐藏；聚焦其他窗口时带到目标屏并聚焦 |
| `Esc` | 使用 FSearch 原生的隐藏动作，最小化窗口，保持进程常驻 |
| 任务栏 pin / 应用菜单 | 显示已有窗口；服务未运行时启动服务后显示 |
| 任务栏右键关闭 / `Alt+F4` | KWin 拒绝关闭主窗口 |

唤起位置优先取当前活动窗口所在屏；从任务栏恢复时保留先前活动窗口所在屏。没有普通活动窗口时取记录的屏幕或鼠标所在屏。

窗口宽度为目标屏逻辑宽度的 **1/2**，水平居中。顶部与本机自由浮动的 KRunner 上边缘对齐；底部对齐该屏可见任务栏的上边缘。每次唤起都重新计算，不固定绑定某一块屏幕。两块屏幕的分数缩放均已验证。

标题栏以及最小化、最大化、关闭按钮全部隐藏。FSearch 改用原生菜单栏布局，把搜索框移到内容区，KWin 移除服务端装饰。文件、编辑等应用菜单保留；窗口关闭保护作用于 KWin 的关闭请求，应用菜单的退出和 `Ctrl+Q` 仍保留原义。首选项等对话框不受主窗口关闭规则限制。

现有无标题栏布局和 KWin 效果没有可直接设置的独立圆角选项，因此本机原型保留当前边角，没有追加 15px 圆角。

## 实现

`src/fsearch-drawer.service` 在 Plasma 图形会话登录时启动 `/usr/bin/fsearch --minimized`，由 systemd 维护进程。异常退出后重启；注销时随图形会话停止。正常隐藏不停止服务。

`src/kwin/fsearch-drawer/contents/code/main.js` 注册全局快捷键，管理主窗口的显示、聚焦、屏幕和尺寸。Esc 继续使用 FSearch 的 `exit_on_escape=false` 配置，不注册全局 Esc。Wayland 调整尺寸是异步的，脚本等窗口确认目标几何后才显示，避免跨屏时闪出旧尺寸。

KWin 规则只匹配 FSearch 普通主窗口，强制无边框、不可关闭、不可最大化。主窗口继续出现在任务栏中，任务栏恢复已有窗口时也会重新定位。原来 GUI 设置的 FSearch 窗口激活快捷键规则由这组规则和脚本替换，避免同一按键重复注册。

`src/fsearch-drawer` 是应用入口，调用脚本的“显示”动作。本地 desktop 文件继续使用 `io.github.cboxdoerfer.FSearch.desktop`，因此原来的任务栏 pin 无需重建。

## 本机部署与恢复

```bash
python3 try-local.py apply
python3 try-local.py status
python3 try-local.py rollback
```

`apply` 会重启一次 FSearch 以切换布局，之后的唤起与隐藏不重启应用。首次修改前把相关文件、FSearch 配置键和窗口规则保存在 `~/.local/state/fsearch-drawer/local-prototype-v1/`；重复 apply 不覆盖快照。rollback 恢复这些内容，并归档已使用的快照。

当前脚本面向这台机器的 Plasma 6、systemd 用户服务和 `/usr/bin/fsearch`。待本机交互审阅通过后再整理跨机器安装方案。

验证记录见 [artifacts/verification.json](artifacts/verification.json)；登录自启已检查启用状态及服务重启后的隐藏行为，尚未通过实际注销或重启整机验证。
