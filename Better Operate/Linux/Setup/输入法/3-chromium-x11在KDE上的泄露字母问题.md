# Chromium/Electron X11 应用在 KDE Wayland 上偶发漏字母

## 现象

环境是 Fedora 44 + KDE Plasma 6 Wayland + Fcitx5-Rime。ChatGPT/Codex 桌面版基于 Chromium/Electron：

- 连续输入中文，偶发漏下 `e`、`n` 等字母在外面，。
- chatgpt 在原生 Wayland 启动参数下，Fcitx5 完全无法连接输入框。
- 单纯加 `--ozone-platform=x11` 后仍可能漏字。


## 排查结论

这是应用输入路径的组合问题，而不是白霜词库问题：

```text
KDE Wayland 会话
  └─ Electron/Chromium 以 X11（XWayland）运行
       ├─ XIM：XMODIFIERS=@im=fcitx
       └─ GTK IM module：GTK_IM_MODULE=fcitx
```

核心原因是 ，一按键经过两条输入法路径，故而有些英文会裸露在中文输入单词的前面。

在本机实测中，可靠组合是：

- 强制 Electron 使用 X11 Ozone 后端；
- 针对该应用启用 Fcitx GTK 输入模块；
- 仅针对该应用禁用 XIM，避免同一按键经过两条输入法路径。

最终命令：

```bash
env GTK_IM_MODULE=fcitx XMODIFIERS=@im=none \
  chatgpt --ozone-platform=x11
```

注意：`XMODIFIERS=@im=none` 只能写在该应用的启动项中，不要改成整个桌面会话的全局值。全局仍保持 `XMODIFIERS=@im=fcitx`，供其他 X11/XWayland 程序使用。

## 固化到 KDE 应用菜单

不要编辑 `/usr/share/applications/chatgpt.desktop`，因为 RPM 升级会覆盖它。将同名启动项复制到用户目录，再修改 `Exec`：


```text
~/.local/share/applications/chatgpt.desktop (menu)
```
```text
~/Desktop/ChatGPT.desktop    (Desktop)
```


关键内容：

```ini
[Desktop Entry]
Name=ChatGPT
Exec=env GTK_IM_MODULE=fcitx XMODIFIERS=@im=none chatgpt --ozone-platform=x11 %U  # important
Icon=chatgpt
Type=Application
StartupNotify=true
```

同名的用户启动项会覆盖系统启动项。修改后刷新 KDE 应用菜单：

```bash
update-desktop-database ~/.local/share/applications
kbuildsycoca6
```







## 无效或不稳定的尝试

- 只升级 ChatGPT：问题仍出现。
- 只加 `--ozone-platform=x11`：仍可能漏字。
- 原生 Wayland + `--enable-wayland-ime`：本机版本中输入框无法稳定连接 Fcitx5。
- 只修改 KDE 应用菜单启动项：桌面图标仍可能引用另一份旧文件。
- 修改启动项后不退出旧进程：旧进程继续使用旧环境。

## 回滚

删除用户级同名启动项后，KDE 会重新使用 `/usr/share/applications/chatgpt.desktop`。桌面图标则把 `Exec` 改回 `chatgpt %U`。回滚后刷新应用菜单并完全重启应用。

## 参考

- [Fcitx5 官方 Wayland 说明](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland)
- [fcitx5-rime](https://github.com/fcitx/fcitx5-rime)
