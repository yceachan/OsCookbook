fcitx5 与各类GUI app 兼容集成 工作区。

探测GUI架构，拟定修复的环境变量启动参数，应用到$share/applications 和 ~/Desktop，后者是前者的软链接。

如果只有usr/share 入口，在$share/applications 创建新快捷方式，便于覆盖系统级的检索。然后ln -sf 到~/desktop