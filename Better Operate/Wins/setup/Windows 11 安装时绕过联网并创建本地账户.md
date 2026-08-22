---
title: Windows 11 安装时创建本地账户
source: https://www.freedidi.com/21151.html
source_title: 绕过微软联网账号的限制！用本地用户安装 Windows 11 系统，最新 3 种方法！
source_published: 2025-10-18
captured: 2026-07-21
tags:
  - Windows 11
  - OOBE
  - 本地账户
  - 系统安装
---

# Windows 11 安装时创建本地账户

> 目标：在 Windows 11 首次开机设置（OOBE）阶段创建本地账户，避免使用 Microsoft 账户登录。

## 背景

Windows 11 的安装流程会因版本和更新而更严格地要求联网及 Microsoft 账户。本文整理了来源文章列出的三种创建本地账户方式；不同版本、语言和安装介质的实际表现可能不同。

## 方法 1：专业版 / 企业版使用“工作或学校”设置

**适用：** Windows 11 专业版或企业版，且安装界面显示相应选项。

1. 在账户用途页面选择 **“为工作或学校设置”**，不要选择个人使用。
2. 进入下一页后，选择 **“改为域加入”**（Domain join instead）。
3. 按向导创建本地用户名和密码。

## 方法 2：离线设置 `BypassNRO` 注册表项

**适用：** 无法联网、安装家庭版，或方法 1 不可用时。

1. 先断开网络：拔掉网线，并关闭 Wi-Fi。
2. 在要求登录账户的 OOBE 页面按 <kbd>Shift</kbd> + <kbd>F10</kbd> 打开命令提示符。
3. 输入以下命令：

   ```bat
   reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE /v BypassNRO /t REG_DWORD /d 1 /f
   ```

4. 立即重启：

   ```bat
   shutdown /r /t 0
   ```

5. 重启后继续 OOBE，选择离线 / 有限设置（若页面提供），然后创建本地账户。

## 方法 3：在 OOBE 中直接创建本地管理员

**适用：** 需要跳过大部分账户创建步骤、快速进入本地账户的场景。

1. 在安装界面按 <kbd>Shift</kbd> + <kbd>F10</kbd> 打开命令提示符。
2. 将下列命令中的 `你的用户名` 替换为实际用户名后依次执行：

   ```bat
   net user 你的用户名 /add
   net localgroup Administrators 你的用户名 /add
   cd OOBE
   msoobe && shutdown -r
   ```

3. 系统重启后，使用刚创建的本地账户继续或进入系统。

## 注意事项

- 命令应仅在 Windows 安装的 OOBE 阶段执行。
- 第 3 种方法会把该账户加入本机管理员组；请设置强密码，并只在受信任的设备上使用。
- `Administrators` 组名在某些本地化系统中可能不同；若加组命令失败，先用 `net localgroup` 查看本机组名。
- Windows 更新可能改变或移除这些入口。若某种方式失效，优先尝试其他方法，或使用对应版本的安装介质重新测试。

## 来源

- 零度博客，2025-10-18：[绕过微软联网账号的限制！用本地用户安装 Windows 11 系统，最新 3 种方法！](https://www.freedidi.com/21151.html)
