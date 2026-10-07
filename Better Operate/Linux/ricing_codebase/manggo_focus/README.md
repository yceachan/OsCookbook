# Manggo 后台窗口唤回

本机原型已应用。Manggo 窗口切到后台后，按 Ctrl+Shift+Q 可以重新切到前台并获得键盘焦点。

规则来源是 `manggo-focus.kwinrule`。本机将其中的 `manggo-focus-activation` 规则合并到 `/home/pi/.config/kwinrulesrc`，并通过 KWin 的 `reconfigure()` 加载。匹配条件是窗口类名 `com.pylogmon.Manggo`。该规则将此应用的焦点抢占防护强制设为“无”。因此，Manggo 的其他窗口激活请求也会被放行。其他应用的防护配置保持原值。

[规则文件](manggo-focus.kwinrule) 的注释记录了每行的作用、各字段的数字取值和 KWin 源码依据。修改数字前，先查看该字段自己的取值表。

2026-10-05 验证环境：KDE Wayland，KWin 6.7.5，Manggo 1.0.2。测试通过本机已有的 `/dev/uinput` 权限发送 Ctrl+Shift+Q 和 Esc，并从 KWin 读取窗口标识、焦点与提醒状态。

停用专用规则后，后台窗口的 `active=false`，`demandsAttention=true`，复现任务栏提醒且窗口没有获得焦点的故障。恢复规则后，同一个后台窗口连续三次唤回，均为 `active=true`、`demandsAttention=false`。按 Esc 后窗口退出显示，再次唤出也能获得焦点。原有三条窗口规则的内容保持不变。

临时诊断文件和验证记录在 `/tmp/manggo-focus-20261005/`。修改前的配置备份是其中的 `kwinrulesrc.before`。撤销此原型时，只删除本机配置中的 `manggo-focus-activation` 规则及其 General 索引，再重新加载 KWin 配置。不要用旧备份覆盖后续新增的其他规则。

当前阶段供本机审阅。审阅通过后再整理跨机器安装与回滚脚本。
