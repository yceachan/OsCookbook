# WT_PD_drawer

一个可审计、可迁移的 Windows Terminal 下拉终端：

- `Win + \`` 显示或隐藏专用终端窗口。
- 抽屉位于前台时，`Ctrl + Shift + F` 将当前会话无损迁移到使用默认布局的普通 Terminal 窗口，并解除服务托管。
- 专用窗口默认使用 `90 × 15`、位置 `373,0` 和 Focus 模式。
- 普通 `Win + R → wt` 始终创建正常的独立窗口。
- 在专用终端执行 `exit` 后，下次按热键会重新创建实例。
- 不分发预编译 EXE；常驻程序和安装器均为可读的 PowerShell 源码。
- 每次启动终端的完整命令都记录在 `%LOCALAPPDATA%\WT_PD_drawer\drawer.log`。

## 安装

在 PowerShell 中运行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install-WTPDDrawer.ps1
```

指定 Profile、工作目录和尺寸：

```powershell
.\Install-WTPDDrawer.ps1 `
  -Profile PowerShell7 `
  -StartingDirectory C:\Eachan `
  -Columns 90 `
  -Rows 15 `
  -X 373 `
  -Y 0
```

安装器会：

1. 备份 Windows Terminal 的 `settings.json`。
2. 移除旧的 Terminal `globalSummon` 并显式取消默认 Quake 绑定，防止争抢 `Win + \``。
3. 添加内部迁移动作，将抽屉标签页移动到新的普通窗口。
4. 恢复普通 Terminal 的窗口设置，并设置 `windowingBehavior=useNew`。
5. 将源码运行时和 `config.json` 安装到 `%LOCALAPPDATA%\WT_PD_drawer`。
6. 在 `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` 注册透明可见的 PowerShell 启动命令。
7. 如发现旧版 `DropdownTerminalHotkey.exe`，停止它并把目录移动到带时间戳的备份目录。

默认配置使用当前用户主目录和 Windows Terminal 的默认 Profile，因此可以跨机器使用。`config.example.json` 展示了全部配置项。

## 卸载

```powershell
.\Uninstall-WTPDDrawer.ps1
```

卸载器默认恢复安装前备份的 Terminal 设置。若希望保留当前 Terminal 设置：

```powershell
.\Uninstall-WTPDDrawer.ps1 -KeepTerminalSettings
```

## 工作原理

常驻 PowerShell 程序使用 Windows `RegisterHotKey` 注册 `Win + \``。按键时：

- 找到标题标记为 `__WT_PD_DRAWER__` 的窗口：切换显示/隐藏。
- 找不到窗口：执行带 `--size`、`--pos`、`--focus` 和独立窗口名的 `wt.exe` 命令重新创建。

这使窗口尺寸与普通 Terminal 的全局配置完全分离，同时不依赖 Terminal 进程在 `exit` 后继续存活。

运行时只在受管抽屉位于前台时拦截 `Ctrl + Shift + F`；抽屉未聚焦时按键会原样放行，因此普通 Terminal 中的查找快捷键和其它应用不受影响。迁移通过 Terminal 自身的 `moveTab` 动作完成，活动 shell 不会重启。抽屉默认只有一个标签页，因此会完整变成普通窗口；若手动创建了多个标签页，快捷键只迁移当前活动标签页，其余标签页也会脱离服务托管。
