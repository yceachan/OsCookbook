# Chrome F1 按键配置

本机 Fedora 44、KDE Wayland 使用 xremap 0.15.15 KDE 版本，在 Chrome 窗口中将单独按下的 F1 绑定到 Snipaste 截图。其他应用继续使用 Snipaste 原有的 F1 快捷键，带修饰键的 F1 组合键继续按原有绑定处理。

`config.yml` 通过 Chrome 的窗口 class 匹配应用，`exact_match: true` 将拦截范围限定为单独的 F1。匹配时，xremap 消费按键并调用本机 Snipaste AppImage 的 `snip` 命令，Chrome 不再收到 F1。Snipaste 需要已在后台运行；其登录自启动由 `~/.config/autostart/Snipaste.desktop` 提供。AppImage 升级并更名时，需同步修改配置中的路径。

配置和用户服务文件从本目录链接到 `~/.config/`，修改后可重启服务生效。

```bash
systemctl --user restart xremap-chrome.service
systemctl --user status xremap-chrome.service
```

服务随图形会话启动，支持配置文件变更和键盘热插拔。`70-xremap-keyboard.rules` 通过 logind 为当前活动的本地桌面用户授予键盘事件设备和 uinput 的访问权限；安装位置为 `/etc/udev/rules.d/70-xremap-keyboard.rules`。

暂停与恢复：

```bash
systemctl --user stop xremap-chrome.service
systemctl --user start xremap-chrome.service
```

取消自动启动并立即停止：

```bash
systemctl --user disable --now xremap-chrome.service
```

上游：[xremap](https://github.com/xremap/xremap)、[KDE 版本下载](https://github.com/xremap/xremap/releases/tag/v0.15.15)、[Snipaste 命令行选项](https://github.com/Snipaste/feedback/wiki/Command-Line-Options)。
