---
title: 从 msixbundle 重装 WSL 平台且保留发行版数据
tags: [WSL, WSLg, msixbundle, Add-AppxPackage, 故障札记]
desc: wsl --update 导致 MSI 半截安装后，用 msixbundle 绕过 winget 重装平台、保住 ext4.vhdx 的修复全流程
update: 2026-07-18
---

# 从 msixbundle 重装 WSL 平台且保留发行版数据

> [!note]
> **Ref:** [WSL GitHub Releases](https://github.com/microsoft/WSL/releases)、本地实战修复记录（2026-07-18）

## 故障背景：一次 `wsl --update` 搞崩整链路

起点是 WSL 里跑图形应用，WSLg 自己崩了。接着 `wsl --update` 想修，结果把整个 WSL 平台更新到「半截状态」，所有 `wsl` 命令都跑不了。崩在半截的原因是 WSL 现在不再是「Windows 内置组件」，而是 **Store/MSI 应用**，`wsl --update` 实际上是对这个 MSI 包做就地升级重装。

### MSI 升级非原子导致的「半截态」

MSI 升级流程大致是：

1. 卸载旧版本 COM classCLSID 注册
2. 删除旧二进制
3. 安装新二进制
4. 写入新的 COM 注册

**四步不是事务**。中途失败（网络断包没下完、MSI Installer 服务异常、杀软拦截文件替换、或正好有 WSLg GUI 应用占着文件句柄）就会卡在中间，老注册被删、新注册没建上 → `wsl.exe` 调 COM 时报 `REGDB_E_CLASSNOTREG`。本次正好是 WSLg 崩了之后系统里残留未被回收的 `wslservice.exe` / `wslhost.exe` 挡住 MSI 文件替换，把概率拉上来了。

## 关键认知：平台与发行版是两个独立包

- `Microsoft.WSL` → 平台/内核包，`wsl --update` / `winget install` 动的都是它
- `CanonicalGroupLimited.Ubuntu22.04LTS_*` → 发行版包，数据本体 `ext4.vhdx` 在它的 `LocalState\` 目录里

**卸载重装 `Microsoft.WSL` 全程不碰发行版包，不碰 `ext4.vhdx`。** 真正会删 vhdx 的只有 `wsl --unregister <发行版>` 和 `Remove-AppxPackage` 发行版包——本次修复全程禁用这两条。

## 定位 vhdx（数据本体）

注册表最准：

```powershell
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss" /s /v BasePath
```

每个发行版一个子键，`BasePath` 指向的目录里有 `ext4.vhdx`。本机示例：

```
C:\Users\yceachan\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu22.04LTS_79rhkp1fndgsc\LocalState\ext4.vhdx  (128G)
```

修复前先把这个文件**复制一份到别处**做底线备份，确认有额外空间再动平台。

## winget 这条路被堵死的经过

按顺序尝试 `winget` 路线，每一项都失败、且失败点不同（说明本机 winget→MSI→AppX 链路有问题）：

1. 直接重装 → `0x800cfb`（已有版本挡住，AppX 残留）
2. `winget install -e --force` → 仍 `0x80073cfb`
3. `Get-AppxPackage *WSL*` 查不到包 → 残留不在当前用户视图
4. `winget install -e --uninstall-previous --verbose` → 95% 报 `0x80073cf1`（Package was not found，MSI 内部提取出 msixbundle 后 AppX 部署服务找不到临时文件）
5. 修复途中还遇到 MSI 要写 `\SOFTWARE\Classes\Directory\shell\WSL`（资源管理器右键菜单）注册表项失败 → `ERROR_INSTALL_FAILURE`，需要管理员权限 + 手动清那个键

结论：**winget/MSI 链路在本机已不可靠，换 Add-AppxPackage 装 msixbundle 绕过去。**

## 正解：msixbundle + Add-AppxPackage

```powershell
# 1. 管理员 PowerShell，从 GitHub Release 下载 msixbundle
#    https://github.com/microsoft/WSL/releases  选稳定版、x64 架构

# 2. 原生 AppX 部署（不经 MSI，绕开右键菜单注册表依赖）
Add-AppxPackage "C:\Users\yceachan\Downloads\Microsoft.WSL_<版本号>_x64.msixbundle"

# 3. 验证（切勿再 wsl --update）
wsl --version
wsl -l -v
wsl -d Ubuntu-22.04
```

`Add-AppxPackage` 走 AppX 原生部署通道，不走 MSI→AppX 桥接，之前卡住的注册表键 / COM 注册问题都能绕过。

## 兜底：发行版注册被蹭掉时复用 vhdx

若 `wsl -l -v` 列不出 Ubuntu-22.04（`--uninstall-previous` 偶尔会蹭掉发行版注册，但 vhdx 还在），用 in-place 重新挂载，不破坏文件内容：

```powershell
wsl --shutdown
wsl --import-in-place Ubuntu-22.04 `
  "C:\Users\yceachan\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu22.04LTS_79rhkp1fndgsc\LocalState\ext4.vhdx"
```

老版本 WSL 不支持 `--import-in-place` 时再退回「重装同名发行版生成新 vhdx → `wsl --shutdown` → 用备份 vhdx 覆盖 → 重启」土办法。

## 收尾：设回默认发行版

平台重装后默认发行版可能丢失标记，`wsl` 直接进会落到内置 fallback 或报错，需要显式指定 `-d` 才能进：

```powershell
wsl --set-default Ubuntu-22.04
wsl -l -v   # Ubuntu-22.04 那行前会有 * 标记
```

之后直接 `wsl` 即可进入。

## 经验沉淀

- **底线三件套**：动平台前先备份 `ext4.vhdx`；全程不 `wsl --unregister`、不 `Remove-AppxPackage` 发行版包；不动 `CanonicalGroupLimited.*` 这个包
- **`wsl --update` 出问题几乎都是 MSI 半截安装**，修复正解是「彻底卸干净再装」而非反复 update
- **winget/MSI 链路不稳时直接上 `Add-AppxPackage` 装 `.msixbundle`**，是绕开 MSI→AppX 桥接的最稳路径
- **GUI 应用（WSLg）崩了先 `wsl --shutdown`** 再做任何平台操作，避免残留句柄挡住 MSI 文件替换
- 平台修复稳定运行一段时间后，再考虑更新；更新前务必 `wsl --shutdown` 关干净所有实例