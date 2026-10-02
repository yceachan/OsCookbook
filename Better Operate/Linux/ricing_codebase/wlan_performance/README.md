# wlan_performance

将本机 Realtek RTL8852BE（`rtw89`）WLAN 固定为最佳性能：全局关闭 NetworkManager Wi-Fi 节能，关闭驱动低功耗模式，并关闭 WLAN PCIe 的 CLKREQ、ASPM L1/L1SS。

## 使用

依赖：NetworkManager、`iw`、`pkexec`，以及已加载的 `rtw89_core`、`rtw89_pci` 模块。

```bash
./manage.sh apply
./manage.sh status
./manage.sh rollback
```

`apply` 和 `rollback` 会通过 KDE/Polkit 请求管理员授权；`status` 不需要提权。

首次 `apply` 会在 `/var/lib/ricing-wlan-performance/active/` 保存真实的安装前状态，包括同名系统配置、所有 Wi-Fi profile、接口节能状态和驱动参数。重复执行 `apply` 不会覆盖这份快照。成功 `rollback` 后，快照移入 `history/`，便于追溯。

## 配置来源

- `src/NetworkManager/10-wifi-performance.conf`：安装到 `/etc/NetworkManager/conf.d/`。
- `src/modprobe.d/rtw89-performance.conf`：安装到 `/etc/modprobe.d/`。

运行时参数会立即更新；持久配置在后续连接和驱动加载时继续生效。脚本不会主动断开 Wi-Fi、卸载驱动或重启系统。
