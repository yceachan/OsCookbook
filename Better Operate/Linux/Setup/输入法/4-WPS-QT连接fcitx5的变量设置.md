WPS 是个特殊案例：它自带一套私有的 Qt 5.12.12，库名被改过（libQt5CoreKso.so.5、libQt5GuiKso.so.5……），跑在 XWayland 的 xcb 平台上。因此系统里那个 /usr/lib64/qt5/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so 根本加载不进去（库名和 ABI 都对不上）。

WPS 于是自带了一个打过补丁的插件：

```
/opt/kingsoft/wps-office/office6/qt/plugins/platforminputcontexts/libfcitxplatforminputcontextplugin.so
```

它的符号名带 `kso_qt` 前缀，内部通过 D-Bus 连 fcitx5。**只有设置 `QT_IM_MODULE=fcitx`，Qt 才会去加载它。**



## Fixup

```
Exec=env QT_IM_MODULE=fcitx GTK_IM_MODULE=fcitx XMODIFIERS=@im=fcitx /usr/bin/wps %U
```

