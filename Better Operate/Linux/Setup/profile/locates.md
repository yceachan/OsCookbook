# Fedora：GUI 使用中文，Shell 消息使用英文

目标：Fedora 桌面和从应用菜单启动的 GUI 软件使用中文，但终端中的 Git、DNF、systemctl 等 CLI 工具显示英文消息。

实现方式是先把桌面会话设置为中文，再只在交互式 Shell 中覆盖消息语言：

```text
系统/桌面会话：zh_CN.UTF-8
        ├── 从应用菜单启动的 GUI：中文
        └── 终端中的 Shell：LC_MESSAGES=C.UTF-8 → 英文消息
```

## 1. 安装中文语言支持

```bash
sudo dnf install langpacks-zh_CN glibc-langpack-zh
```

确认中文 locale 可用：

```bash
locale -a | grep -i zh_CN
```

通常会看到类似：

```text
zh_CN.utf8
```

## 2. 把 Fedora GUI 设置为中文

### 方法一：使用 GNOME 设置

打开：

```text
设置 → 系统 → 区域与语言 → 语言
```

选择“中文（中国）”，然后注销并重新登录。某些 Fedora/GNOME 版本中，“区域与语言”可能直接位于设置主页面。

### 方法二：使用命令行

```bash
sudo localectl set-locale LANG=zh_CN.UTF-8
```

然后注销并重新登录。检查桌面会话的默认 locale：

```bash
localectl status
```

不要把系统 locale 设置成英文，否则新启动的 GUI 应用也可能变成英文。

## 3. 只把 Shell 消息覆盖为英文

推荐只覆盖 `LC_MESSAGES`。这样命令的提示、警告和错误消息会使用英文，但日期、数字、货币和排序规则仍沿用中文 locale。

### Bash

在 `~/.bashrc` 末尾加入：

```bash
# Keep the desktop locale Chinese, but show CLI messages in English.
unset LC_ALL
unset LANGUAGE
export LC_MESSAGES=C.UTF-8
```

让当前终端立即生效：

```bash
source ~/.bashrc
```

### Zsh

在 `~/.zshrc` 末尾加入同样的内容：

```zsh
# Keep the desktop locale Chinese, but show CLI messages in English.
unset LC_ALL
unset LANGUAGE
export LC_MESSAGES=C.UTF-8
```

让当前终端立即生效：

```zsh
source ~/.zshrc
```

`C.UTF-8` 同时提供英文消息和 UTF-8 字符支持，一般不需要额外安装英文语言包。也可以使用 `en_US.UTF-8`；如果该 locale 不存在，先安装并确认：

```bash
sudo dnf install glibc-langpack-en
locale -a | grep -i en_US
```

然后改为：

```bash
export LC_MESSAGES=en_US.UTF-8
```

## 4. 验证配置

重新打开终端，执行：

```bash
locale
git status
systemctl status NetworkManager
```

预期结果：

- `LANG=zh_CN.UTF-8`：桌面会话的基础语言仍是中文。
- `LC_MESSAGES=C.UTF-8`：终端命令的消息使用英文。
- 其他 `LC_*` 项目仍由 `LANG=zh_CN.UTF-8` 决定。

例如，`locale` 的关键输出可能类似：

```text
LANG=zh_CN.UTF-8
LC_MESSAGES=C.UTF-8
LC_ALL=
```

`LC_ALL` 必须保持未设置状态，因为它的优先级最高；如果设置了 `LC_ALL=zh_CN.UTF-8`，它会覆盖 `LC_MESSAGES`。GNU gettext 程序还可能优先读取 `LANGUAGE`，所以也要取消已有的 `LANGUAGE=zh_CN`。

locale 变量的常见优先级可以简化理解为：

```text
LC_ALL > 对应的 LC_* > LANG
```

对于使用 GNU gettext 的程序，还要留意 `LANGUAGE`。

## 5. 从终端启动 GUI 软件时的注意事项

应用菜单启动的 GUI 软件不会读取 `~/.bashrc` 或 `~/.zshrc`，因此仍然显示中文。

但是，从终端启动的 GUI 软件会继承 Shell 的 `LC_MESSAGES=C.UTF-8`，其界面可能显示英文。需要临时以中文启动时，可以这样执行：

```bash
LC_MESSAGES=zh_CN.UTF-8 LANGUAGE=zh_CN application-name
```

例如：

```bash
LC_MESSAGES=zh_CN.UTF-8 LANGUAGE=zh_CN gedit
```

也可以在 Shell 配置中加入一个辅助函数：

```bash
zhgui() {
    LC_MESSAGES=zh_CN.UTF-8 LANGUAGE=zh_CN "$@"
}
```

之后使用：

```bash
zhgui gedit
```

## 6. 常见问题

### Git 仍然显示中文

检查所有 locale 变量：

```bash
locale
env | grep -E '^(LANG|LANGUAGE|LC_)='
```

重点确认：

- 没有 `LC_ALL=zh_CN.UTF-8`。
- 没有 `LANGUAGE=zh_CN`。
- `LC_MESSAGES` 确实是 `C.UTF-8` 或 `en_US.UTF-8`。

还可以临时验证 Git 是否支持英文输出：

```bash
LC_ALL=C.UTF-8 LANGUAGE= git status
```

### 某些 CLI 仍不遵循 `LC_MESSAGES`

少数程序只检查 `LANG`，没有正确使用 locale 分类。可以只对该命令临时设置完整英文环境：

```bash
LANG=C.UTF-8 LC_ALL=C.UTF-8 LANGUAGE= command-name
```

如果希望终端内的所有 locale 分类都使用英文，也可以在 Shell 配置中使用：

```bash
unset LC_ALL
unset LANGUAGE
export LANG=C.UTF-8
```

这会影响终端中的日期、数字、排序等格式，因此通常不如只设置 `LC_MESSAGES` 精细。

### 修改后没有生效

确认修改的是当前 Shell 对应的文件：

```bash
echo "$SHELL"
```

- `/bin/bash`：修改 `~/.bashrc`。
- `/bin/zsh`：修改 `~/.zshrc`。

桌面语言修改后需要注销并重新登录；Shell 配置修改后需要重新打开终端或手动 `source` 对应配置文件。
