# Shell Configuration Offline Sync Package

此文件夹包含了将本地 Shell 配置（Oh My Zsh, Powerlevel10k, 插件等）离线同步到远程服务器所需的所有文件。

## 文件说明

- **`shell_sync_pack.tar.gz`**: 核心离线包。包含了 `.oh-my-zsh` 完整目录（含插件/主题）、`.zshrc`、`.p10k.zsh` 以及一个自动安装脚本 `install.sh`。
- **`pack_shell_config.sh`**: 打包脚本。如果您更新了本地配置（如添加了新插件），运行此脚本可重新生成上面的 `.tar.gz` 包。

## 使用指南

### 1. 上传到服务器

使用 SFTP 将压缩包上传到目标服务器（假设文件在当前目录下）：

```bash
# 将 user@host 替换为您的服务器登录信息
echo "put shell_sync_pack.tar.gz" | sftp user@host
```

### 2. 服务器端安装

通过 SSH 登录服务器并执行一键安装命令。此命令会解压并自动备份旧配置：

```bash
ssh user@host "mkdir -p tmp_shell && tar -xzf shell_sync_pack.tar.gz -C tmp_shell && cd tmp_shell && ./install.sh"
```

### 3. (可选) 重新打包

如果您修改了本地的 `~/.zshrc` 或 `~/.oh-my-zsh`，需要重新生成同步包：

```bash
# 在本目录下执行
./pack_shell_config.sh
```

---

**安装脚本行为说明：**
- 脚本会自动检测服务器上现有的 `.zshrc`, `.p10k.zsh`, `.oh-my-zsh`。
- 如果存在，会自动重命名备份（例如 `.zshrc_backup_YYYYMMDD_HHMMSS`）。
- 不需要服务器具备外网连接即可完成所有插件的安装。
