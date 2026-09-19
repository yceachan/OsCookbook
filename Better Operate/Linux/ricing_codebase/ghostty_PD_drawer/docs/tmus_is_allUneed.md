# tmux is all you need

这篇文档只解决一个核心问题：怎样让终端里的工作脱离某个窗口继续存在，并且随时从另一个终端接回来。

项目文件名保留了 `tmus` 的原始拼写；工具的正确名字是 **tmux**，可以理解成 terminal multiplexer（终端复用器）。

## 先建立正确的模型

普通终端大致是这条链：

```text
Ghostty 窗口 → PTY → shell → 你启动的程序
```

关闭 Ghostty 后，PTY 消失，依赖它的 shell 和程序通常也会收到挂断信号。`nohup`、`disown` 可以改变信号关系，但不能保留完整的交互终端。

tmux 在中间增加了一个长期运行的 server：

```text
Ghostty 窗口 → tmux client ─┐
                            ├→ tmux server → session → window → pane → shell/程序
另一个终端   → tmux client ─┘
```

因此：

- **server** 是后台进程，拥有所有伪终端和子进程。
- **session** 是一组工作的容器，例如 `ghostty-pd-drawer`、`project-a`。
- **window** 类似浏览器标签页。
- **pane** 是一个 window 内的分屏，每个 pane 通常运行一个 shell。
- **client** 是当前显示并操作某个 session 的终端窗口。

所谓“把任务 disown 出来”，在 tmux 中更准确地叫 **detach client**：程序仍属于 tmux 的 PTY，只是当前 Ghostty 不再显示它。稍后 attach 一个新 client，就能看到完全相同的终端状态。

## 你的 drawer 已经怎样使用 tmux

按 `Win+\`` 时，drawer 实际执行：

```bash
tmux new-session -A -s ghostty-pd-drawer
```

这条命令可以从参数推出行为：

- `new-session`：创建 session。
- `-s ghostty-pd-drawer`：指定固定名字。
- `-A`：如果同名 session 已存在，则 attach，而不是创建失败。

所以最常用的流程只有三步：

1. `Win+\`` 打开 drawer，在里面启动编译、日志监控或其他长任务。
2. 按 `Ctrl+b`，松开，再按 `d`，从 session 分离。
3. 以后再次按 `Win+\``，或者在任意终端执行 `tmux attach -t ghostty-pd-drawer` 恢复现场。

按 `Win+F` 时，项目会新建普通 Ghostty，并执行等价于：

```bash
tmux new-session -A -D -s ghostty-pd-drawer
```

`-D` 表示先分离这个 session 的其他 client，再由新窗口接管。因此 `Win+F` 是“转移”，不是多开一个镜像。若你本来就在另一台终端查看该 session，它也会被断开。

## Prefix：tmux 快捷键为什么要按两段

tmux 不能随意截获 `Ctrl+c`、方向键等输入，否则终端程序无法正常使用。因此它默认只在收到前缀 `Ctrl+b` 后，把下一次按键解释为自己的命令。

例如 detach 的完整动作是：

```text
按住 Ctrl 并按 b → 全部松开 → 按 d
```

本文把它简写为 `Prefix d`，其中 `Prefix` 默认就是 `Ctrl+b`。它不是同时按 `Ctrl+b+d`。

## 最值得记住的快捷键

### Session

| 按键 | 作用 |
| --- | --- |
| `Prefix d` | detach，任务继续运行 |
| `Prefix $` | 重命名当前 session |
| `Prefix s` | 显示并选择 session |

### Window

| 按键 | 作用 |
| --- | --- |
| `Prefix c` | 新建 window |
| `Prefix n` / `Prefix p` | 下一个 / 上一个 window |
| `Prefix 0`…`9` | 跳到指定编号的 window |
| `Prefix ,` | 重命名当前 window |
| `Prefix &` | 关闭整个 window，会要求确认 |

推荐把一个工作主题放在一个 window：例如 `editor`、`build`、`logs`。当 pane 多到需要反复寻找时，通常新建 window 比继续分屏更清楚。

### Pane

| 按键 | 作用 |
| --- | --- |
| `Prefix %` | 左右分屏 |
| `Prefix "` | 上下分屏 |
| `Prefix 方向键` | 切换 pane |
| `Prefix z` | 放大当前 pane；再次按恢复 |
| `Prefix x` | 关闭当前 pane，会要求确认 |
| `Prefix Space` | 循环切换自动布局 |
| `Prefix {` / `Prefix }` | 向前 / 向后交换 pane |

如果只是暂时想看清日志，优先用 `Prefix z`，不必删除其他 pane。

### 滚动和复制

终端进入 tmux 后，历史滚动属于 tmux pane，不再完全由 Ghostty 管理：

1. `Prefix [` 进入 copy mode。
2. 用方向键、`PageUp`、`PageDown` 浏览历史。
3. 按 `q` 或 `Esc` 离开。

默认复制按键会受到 tmux 的 Emacs/Vi 模式影响。若启用本文后面的 Vi 配置，tmux 默认用 `Space` 开始选择、用 `Enter` 复制并退出，`v` 是矩形选择开关；网上常见的 `v` 开始、`y` 复制属于额外自定义，并非只设置 `mode-keys vi` 就会出现。复制后可用 `Prefix ]` 粘贴 tmux buffer。系统剪贴板是否同步则取决于 tmux、终端和系统剪贴板配置，不能把 tmux buffer 与桌面剪贴板视为同一个东西。

## 不在 tmux 里面时使用的命令

查看所有 session：

```bash
tmux list-sessions
# 简写
tmux ls
```

创建具名 session：

```bash
tmux new-session -s project-a
# 简写
tmux new -s project-a
```

恢复 session：

```bash
tmux attach-session -t project-a
# 简写
tmux attach -t project-a
```

把其他 client 踢下线并接管：

```bash
tmux attach -d -t project-a
```

重命名和删除：

```bash
tmux rename-session -t project-a project-b
tmux kill-session -t project-b
```

`kill-session` 会终止该 session 里的 shell 和程序，不等于 detach。更危险的 `tmux kill-server` 会结束当前用户的所有 tmux session，日常不要使用。

## 一个五分钟练习

先创建练习 session：

```bash
tmux new -s practice
```

在其中运行一个持续输出的循环：

```bash
while true; do date; sleep 1; done
```

然后：

1. 按 `Prefix d` 回到原终端。
2. 执行 `tmux ls`，确认 `practice` 仍存在。
3. 等几秒，执行 `tmux attach -t practice`。
4. 观察时间输出从未停止。
5. 按 `Ctrl+c` 停止循环，再执行 `exit`。

最后一个 pane 的 shell 退出后，session 也会结束。这说明 tmux 保存的是仍在运行的进程和 PTY，并不是终端内容的静态快照。

## 适合长 session 的组织方式

一个实际项目可以这样安排：

```text
session: firmware
├── window 0: editor
│   ├── pane 0: nvim
│   └── pane 1: git status / tests
├── window 1: build
│   └── pane 0: west build / make / ninja
└── window 2: target
    ├── pane 0: serial console
    └── pane 1: OpenOCD / logs
```

这和嵌入式系统里的分层管理类似：session 是整个调试现场，window 按职责分组，pane 才是具体执行单元。这个类比只帮助组织，不代表 tmux 有硬件式隔离；所有进程仍是普通用户进程。

建议：

- session 用项目名，而不是 `test1`、`new`。
- window 用任务名，而不是依赖编号记忆。
- 一个 pane 只承担一个长期角色。
- 离开前用 detach；确认不再需要时才 `exit` 或 `kill-session`。

## 本地 tmux 与远程 tmux

如果在本地 tmux pane 中运行 SSH：

```text
本地 tmux → ssh → 远程程序
```

关闭 Ghostty 不会杀死本地 SSH client，但网络中断仍可能让远程程序退出。真正需要跨断网保留远程任务时，应在服务器上再次运行 tmux：

```text
本地终端 → ssh → 远程 tmux → 远程程序
```

进入嵌套 tmux 后，外层会先收到 `Ctrl+b`。默认配置下，按 `Ctrl+b` 两次可以把一个 `Ctrl+b` 发送给内层；但嵌套层次很容易混淆，应通过状态栏或不同 prefix 明确区分。

## 一份克制的可选配置

本项目不会修改 `~/.tmux.conf`。掌握默认行为后，可以自行加入下面几项：

```tmux
# 鼠标选择 pane、调整边界和滚动历史
set -g mouse on

# 增加每个 pane 的历史行数
set -g history-limit 100000

# window 和 pane 从 1 开始编号，并在关闭后保持连续
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# copy mode 使用 Vi 风格按键
setw -g mode-keys vi
```

让已经运行的 server 重新读取配置：

```bash
tmux source-file ~/.tmux.conf
```

配置解析失败时 tmux 会报错，不要用吞掉错误的启动脚本掩盖问题。

## 常见误区与恢复方法

### `Ctrl+c`、`exit`、detach 不是一回事

- `Ctrl+c`：给当前前台程序发送中断信号。
- `exit` 或 `Ctrl+d`：退出当前 shell；最后一个 pane 退出时 session 会消失。
- `Prefix d`：只断开 client，里面的 shell 和程序继续运行。
- `Win+\``：收起或展开 drawer 窗口，本身不要求 tmux client 断开。
- `Win+F`：在普通 Ghostty 中接管 drawer session，并断开旧 client。

### 找不到 session

先执行：

```bash
tmux ls
```

如果显示 `no server running`，说明当前用户没有 tmux server。常见原因是最后一个 pane 已退出、session 被 kill，或者机器重启了。tmux 默认不提供跨重启恢复；跨重启需要额外的保存/恢复方案，而且不能保证任意进程状态可序列化。

### 不知道自己是否已经在 tmux 中

```bash
printf '%s\n' "$TMUX"
```

非空通常表示当前 shell 位于 tmux pane 中。也可以看状态栏，或执行：

```bash
tmux display-message -p '#S:#I.#P'
```

输出依次是 session、window、pane，例如 `ghostty-pd-drawer:0.1`。

### 忘记快捷键

`Prefix ?` 会显示当前 server 的全部绑定；它比网上的快捷键表更可靠，因为它反映的是你此刻真正加载的配置。

## 最小记忆集

如果只记六件事，记这些：

```text
tmux new -s NAME       创建 session
Prefix d               分离但不停止任务
tmux ls                 查看 session
tmux attach -t NAME    恢复 session
Prefix c               新建 window
Prefix ?               查看当前快捷键
```

其余命令都可以在需要时从这套模型推出：终端窗口只是 client；真正承载任务的是 tmux server 中的 session、window 和 pane。
