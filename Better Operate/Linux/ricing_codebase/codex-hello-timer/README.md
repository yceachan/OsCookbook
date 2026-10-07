# Codex hello timer

每天在本地时区的 07:00、12:00、17:00、22:00 运行一次：

```text
CODEX_HOME="$HOME/.local/share/codex-hello" \
  codex exec --ephemeral --skip-git-repo-check --sandbox read-only \
  --model gpt-5.6-luna --config model_reasoning_effort=low hello
```

独立的 `CODEX_HOME` 仅通过符号链接复用登录认证，不加载主配置中的 `AGENTS.md`、插件或 MCP。`--ephemeral` 避免保存四个无用会话，`--sandbox read-only` 防止这个简单请求修改文件。

## 安装并启用

先确认交互式 Codex CLI 已经登录，然后执行：

```bash
./install.sh
```

查看下次触发时间和运行日志：

```bash
systemctl --user list-timers codex-hello.timer
journalctl --user -u codex-hello.service
```

手动测试一次（这会真实发送 `hello` 并消耗用量）：

```bash
systemctl --user start codex-hello.service
```

停用：

```bash
systemctl --user disable --now codex-hello.timer
```

如果退出登录后也必须运行，需要管理员执行一次：

```bash
sudo loginctl enable-linger "$USER"
```

该定时器只保证在机器和用户级 systemd 正常运行时发起请求；Codex 的用量窗口是否因此锚定或重置由服务端规则决定。
