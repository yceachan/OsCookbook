# Kotofox 本机原型

Kotofox 把 Musicfox、tmux 和 Kotonoha 集成到一个 KDE 应用入口。
本版用于 Fedora 44、KDE Wayland、x86_64 和系统 Qt 6.11。
构建包包含 Musicfox 5.1.0、Kotonoha 0.2.3、歌词原生库和 UniDesktop 托盘库。
Python、PyQt6、qasync、aiohttp、dbus-fast、Ghostty 和 tmux 使用本机已安装的版本。

在本目录执行 `./build-local.sh`。
构建使用 `/tmp`，只下载并解包开发头文件，不安装系统软件包。
输出位于 `.packages/kotofox-0.1.0-fedora44-x86_64.tar.gz`。
上游版本和二进制校验值保存在包内的 `manifest.json`。

把包解压到 `/tmp`，执行解压目录中的 `./try-local.sh`。
执行 `~/.local/bin/kotofox open` 打开播放器。
执行 `~/.local/bin/kotofox manage` 打开管理窗口。
KDE 应用菜单中的入口名为 Kotofox。
可以把该入口固定到任务栏。

Kotofox 复用正常 tmux 服务中的 `musicfox` 会话。
启动时读取现有 tmux 配置。
已有会话直接复用，不启动第二个播放器。
播放器窗口使用 Ghostty，读取现有字体、主题和快捷键配置。
重复打开会恢复同一个窗口。KWin 将该窗口关联到 Kotofox 任务栏入口。
关闭 Ghostty 或按 `Ctrl+Z` 后，播放器继续运行。
右键托盘可以控制播放器窗口、桌面歌词、歌词穿透、歌词设置和播放。
“退出 Kotofox，保留播放”只退出管理进程和歌词。
“退出并停止播放器”还会关闭 `musicfox` 会话。

歌词配置保存在 `~/.config/kotofox/lyrics.json`。
首次启动时复制原 Kotonoha 的外观配置，之后独立保存。
歌词只跟随 Musicfox 的 MPRIS 接口。MPRIS 是桌面的媒体控制接口。
Kotonoha 原有的歌词来源和缓存继续使用。
Kotofox 只显示一个托盘，不注册 Kotonoha 原来的托盘。
单独的 Kotonoha 实例与 Kotofox 共用实例锁，不能同时启动。

UniDesktop 的原版菜单数据格式会导致托盘的 D-Bus 连接中断。
构建脚本直接使用[修复提交 `622436a`](https://github.com/yceachan/SDK/commit/622436a3d665fdd9cfe769fc85b049eadcd38e65)，替换原来的本地补丁。
该提交修正 `GetLayout` 的数据格式和托盘 `Menu` 属性类型，删除无效的空结构。测试覆盖菜单发现和真实 D-Bus 传输。
SDK 源码和构建产物保存在 `/tmp`。包内记录提交和动态库校验值。
本机原 Kotonoha 的歌词库按 Qt 6.10 编译，因此包内重编译了 Qt 6.11 的歌词库。

执行 `python3 -m unittest discover -s tests -v` 检查隔离 tmux 会话的生命周期。
检查试用进程时执行 `~/.local/bin/kotofox status`。
读取进程日志时执行 `journalctl --user -u kotofox.service`。
本次实机结果在 `review.html`，它由 `evidence.json` 生成。
本版提供当前机器的试用包。跨机器安装和回滚流程在功能审阅后处理。
