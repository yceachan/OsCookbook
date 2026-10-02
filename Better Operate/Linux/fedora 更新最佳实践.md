# Fedora 更新最佳实践

适用环境：Fedora KDE 普通 RPM 安装，使用 RPM Fusion 的 `akmod-nvidia`。根据本机 Fedora 44、DNF5、akmods 0.6.2 的行为整理，核对日期：2026-09-26。Atomic／Kinoite 不适用本文流程。

## 日常更新：安装 → 编译 → 检查 → 重启

系统软件统一用 DNF 更新；Flatpak 应用用 `flatpak update` 或 Discover。更新内核或 NVIDIA 驱动后，在当前桌面会话中完成模块编译并检查，再重启。

下文管理员命令使用 `pkexec`，通过 KDE／Polkit 弹窗授权。习惯终端输入密码时，可以把命令开头的 `pkexec` 换成 `sudo`，例如 `sudo dnf upgrade --refresh`，更新行为相同。

### 1. 更新系统软件

先保存工作，接好电源，确认 Discover 没有正在安装系统软件，然后执行：

```bash
pkexec dnf upgrade --refresh
```

查看待更新清单后确认安装，等命令完成。`--refresh` 会重新检查仓库元数据；本条命令直接安装当前 Fedora 版本的可用 RPM 更新，不会自动升级到下一代 Fedora，也不会自动重启。[DNF5 更新文档](https://dnf5.readthedocs.io/en/latest/commands/upgrade.8.html)、[选项说明](https://dnf5.readthedocs.io/en/latest/dnf5.8.html)

### 2. 完成内核模块编译

如果本次更新涉及内核、NVIDIA 或其他 akmod 包，执行：

```bash
pkexec akmods --force
```

本机的 akmods 默认检查下一次启动的默认内核和当前运行内核，为缺失或过期的模块构建并安装 RPM。如果后台已经编译完成，会跳过无需更新的模块。

`--force` 允许重试先前失败的构建；`--rebuild` 才是连最新模块也重新编译，日常更新无需加上。编译期间保持电脑开机，按终端结果判断完成，不依赖“等几分钟”的固定时间。

**区别只在于：是否重试之前失败过的构建。**

| 模块状态                                     | 不带 `--force` | 带 `--force` |
| -------------------------------------------- | -------------- | ------------ |
| 已安装且版本匹配                             | 跳过           | 跳过         |
| 缺失或过期，没有失败记录                     | 编译并安装     | 编译并安装   |
| 当前驱动版本针对该内核曾构建失败，有失败记录 | 跳过并提示     | 重新尝试     |

因此，日常提前编译可以先用：

```
pkexec akmods --akmod nvidia --kernels 目标内核版本
```

如果之前失败过，修复原因后加 `--force` 重试。**`--force` 不会绕过编译错误，也不会把已匹配的模块全部重编；后者需要 `--rebuild`。**

**检查输出中是否有失败或缺少 `kernel-devel` 的提示。** 本机这版 akmods 的部分失败路径不会产生非零退出码，因此不要把它与自动重启命令串在一起。

### 3. 重启前检查 NVIDIA 模块

以下命令适用于本机的 GRUB／grubby 环境，在同一个终端依次运行：

```bash
pkexec grubby --default-kernel
```

输出应类似 `/boot/vmlinuz-7.2.7-200.fc44.x86_64`。把其中的版本填入变量；下面版本只是示例，以本次输出为准：

```bash
update_kernel='7.2.7-200.fc44.x86_64'
modinfo -k "$update_kernel" -F version nvidia
modinfo -k "$update_kernel" -F vermagic nvidia
modinfo -k "$update_kernel" -F filename nvidia_drm
rpm -q --qf '%{VERSION}\n' akmod-nvidia
```

确认 NVIDIA 模块版本与 `akmod-nvidia` 版本一致，`vermagic` 以目标内核版本开头，且 `nvidia_drm` 能查到模块路径。若提示找不到模块、版本不符，或编译有失败提示，先排查再重启。

`uname -r` 显示当前正在运行的内核。更新后尚未重启时，它通常仍是旧版本，不能用它代替新内核进行验证。

这些检查确认模块已经安装并匹配目标版本，实际能否加载仍需启动验证。首次整理本文时，本机 Secure Boot 关闭；若以后开启，还需确保模块签名密钥已登记并受信任。

### 4. 更新 Flatpak，按需重启

```bash
flatpak update
```

DNF 不管理 Flatpak 应用与运行时，这条命令单独更新它们。[Flatpak 文档](https://docs.flatpak.org/en/latest/using-flatpak.html#updating)

内核或 NVIDIA 驱动更新且检查通过后，保存工作，从 KDE 菜单正常重启。只更新普通应用时，通常重新打开相关应用即可。

重启后验证：

```bash
uname -r
nvidia-smi
```

检查是否进入预期内核、显卡驱动是否正常工作。如果启动菜单中主动选择了旧内核，`uname -r` 显示旧版本属于预期结果。

## Discover 已安排“重启并更新”时

本节只在已有离线更新安排、准备改用 DNF 完成本次更新时使用，无需每次执行。

先查看触发链接：

```bash
ls -l /system-update
```

如果它指向 `/var/lib/PackageKit/prepared-update`，说明 PackageKit 已安排下次启动执行离线更新。文件不存在表示这个触发链接没有设置；仅下载好更新包与已安排启动执行，是两个不同状态。[PackageKit 离线更新说明](https://github.com/PackageKit/PackageKit/blob/main/docs/offline-updates.txt)

确认是上述 PackageKit 计划后，取消本次启动触发：

```bash
pkcon offline-cancel
```

需要授权时按 Polkit 提示操作。然后再次查看 `/system-update`，确认触发链接已移除，再按本文日常流程完成更新。取消触发不会卸载软件，也不等于清空已下载的更新缓存；不要手动删除 PackageKit 状态文件。

如果链接指向其他位置，先识别是谁安排了更新，不要照搬取消操作。

提前使用 DNF 安装软件会改变系统包状态，PackageKit 可能使原先准备好的更新计划失效。因此切换到 DNF 后，让 DNF 完成本次系统更新，不依赖原计划继续执行，也不要再在 Discover 中安排同一批系统更新。

## 编译失败时怎么处理

保持当前会话，先看 akmods 给出的错误和日志路径。NVIDIA 构建日志通常在 `/var/cache/akmods/nvidia/`：

```bash
ls -lt /var/cache/akmods/nvidia/
```

打开本次目标内核对应的日志，特别是 `.failed.log`，根据具体错误处理。

如果明确提示缺少目标内核的开发文件，使用前面设置的 `update_kernel`：

```bash
pkexec dnf install "kernel-devel-$update_kernel"
```

安装成功后重试，并重新做模块检查：

```bash
pkexec akmods --force --akmod nvidia --kernels "$update_kernel"
```

`kernel-devel` 必须与目标内核精确匹配；仅有 `kernel-headers` 不够。如果日志显示驱动源码与新内核不兼容，重复编译不会解决问题，应保留可用旧内核，查明兼容性或等待修复。

若重启后遇到黑屏，可从 GRUB 菜单尝试之前可用的内核，再检查日志。旧内核是恢复入口；如果 NVIDIA 驱动也升级了，它的对应模块也需要与新驱动匹配。无需在日常更新中手动删除旧内核、强制重建 initramfs 或卸载显卡驱动。

## 使用边界

本文适合希望在重启前查看编译结果的日常更新流程。在线更新会让仍在运行的旧程序与磁盘上的新软件短暂并存；涉及内核、驱动或桌面核心组件时，更新并检查完成后安排重启。

Fedora 大版本升级应单独按当时的官方升级指南操作。BIOS／UEFI 等通过 fwupd 分发的设备固件，也不在 `dnf upgrade` 的完整管理范围内。

实现核对依据：本机 `/usr/bin/akmods`、`akmods --help`、PackageKit 的 D-Bus `Cancel` 接口说明，以及 [PackageKit 对离线更新失效的处理](https://github.com/PackageKit/PackageKit/blob/v1.4.0/src/pk-engine.c#L355)。本文件只记录流程，创建文档没有执行系统更新、取消计划或重启操作。
