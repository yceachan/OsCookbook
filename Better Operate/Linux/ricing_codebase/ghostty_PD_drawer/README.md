# ghostty_PD_drawer

面向 KDE Plasma 6 Wayland 的 Ghostty 下拉终端。drawer 使用专用的无标题栏配置，不使用 tmux。

## 行为

| 快捷键 | 行为 |
| --- | --- |
| `Meta+\`` | 显示或收起当前 drawer；没有 drawer 时启动一个新实例 |
| `Esc` | 仅在 shell 提示符下隐藏 drawer；运行 vim、less、REPL 等程序时 Esc 原样交给程序 |
| `Meta+F` | 将当前 drawer 原地迁移成普通 Ghostty 窗口（drawer 已隐藏、或键盘焦点被全屏程序占用时同样生效） |

`Esc` 不经过任何 Ghostty 键绑定消费，而是 drawer shell 里的一个 ZLE widget（见下文）：内建的 `performable:escape=end_search` 只在搜索进行中才消费按键，空闲时 Esc 会正常送到 PTY。因此在任何前台程序里它都不会被吞掉；迁移成普通窗口或 drawer 已被关闭后，controller 会拒绝隐藏请求，`Esc` 完全交还给程序。

每个 drawer 启动前，controller 会为这个实例写一份只包含 `config-file` 引用的配置（用户的 `config`、`config.ghostty`，drawer 再追加 `dropdown.ghostty`），Ghostty 自己按顺序展开。**不用 `ghostty +show-config` 拍平**：拍平会丢掉键绑定属性，内建的 `performable:escape=end_search` 会退化成会吞 Esc 的普通绑定。迁移时把该引用改成只留用户配置，通过对应 systemd unit 向这一个 Ghostty 进程发送 `SIGUSR2`，再撤销 KWin 设置的无边框、置顶、任务栏隐藏和固定尺寸属性，并把窗口恢复为普通尺寸。因此同一个 Ghostty 进程、PTY、shell、前台任务和滚动缓冲区都会保留，配置则热重载为默认配置。

迁移后的窗口尺寸不再由 KWin 拍脑袋决定，而是按主终端配置里的 `window-width` / `window-height` 计算：controller 从 drawer 的 PTY 读取真实网格（`TIOCGWINSZ`，含 `ws_xpixel`/`ws_ypixel`）来标定字体单元格尺寸，再用 Ghostty 自己的公式 `ceil(格数 × 单元格) + padding` 算出窗口大小。实测（drawer 网格 86×16，frame 853×340，cell 9.640×19.438）：controller 返回 `(988, 647)`，迁移后窗口实测 988 × 646.667、居中在 drawer 原本那块屏（eDP），网格变成 100 列 × 30 行（标签栏+标题栏占掉约两行），Ghostty 进程号不变。算不出尺寸时返回 `(0, 0)`，KWin 侧回退到自己的默认几何。

`Meta+F` 作用于当前的 drawer：它不需要 drawer 处于聚焦状态（全屏游戏会长期占用焦点），也可以在 drawer 被 `Esc` 隐藏后直接把它迁移出来；迁移落地在 drawer 自己所在的那块屏，不会跳到当前聚焦屏。迁移后的窗口从 drawer 管理集合中永久移除，对它再次按 `Meta+F` 不会产生动作。下一次 `Meta+\`` 会生成新的实例配置并启动另一个 Ghostty 进程和 systemd unit，与旧终端没有 tmux session、PTY 或进程复用关系。

KWin 脚本被重新加载时（apply、Plasma 重载脚本），已经在运行的 drawer 会被重新接管并保持原状：隐藏的仍然隐藏、可见的不会被拽到别的屏，避免重载把 drawer 甩到当前聚焦的显示器上。

## 圆角来自 GTK 主题

drawer 使用和主终端相同的 `window-decoration = client`（客户端装饰），只是关掉了标题栏和标签栏。于是窗口带着 `window.csd` 样式类，Breeze GTK 主题的 `window.csd { border-radius: 5px }` 直接生效——圆角不是写死的数值，而是和主终端共用同一来源，改主题两边一起变。因此本功能不再安装 `dropdown.css`；升级时 apply 会把它删除，快照里仍保留以便 rollback。

drawer 的其余外观（主题、字体、字号、padding、透明度）都不再重复配置，全部跟随 `~/.config/ghostty/config` 与 `~/.config/ghostty/config.ghostty`。drawer 只覆盖真正属于它的项：工作目录、无标题栏、`window-width/height = 0`（尺寸交给 KWin 窗口规则，避免 Ghostty 的默认窗口尺寸和规则互相打架）。

## Prompt 上的 Esc

drawer 实例的 systemd unit 会设置 `ZDOTDIR` 与 `GHOSTTY_PD_DRAWER_INSTANCE`。Ghostty 的 zsh shell integration 本来就用 `ZDOTDIR` 注入自己，并会把原有值搬进 `GHOSTTY_ZSH_ZDOTDIR` 后还回来，所以 zsh 随后读到的是本功能安装的 overlay：

```text
~/.local/share/ghostty-pd-drawer/zdotdir/
├── .zshenv   -> ~/.zshenv     （符号链接，用户文件行为不变）
├── .zprofile -> ~/.zprofile
├── .zlogin   -> ~/.zlogin
└── .zshrc                      （source 用户 .zshrc 后追加 Esc 绑定）
```

overlay 的 `.zshrc` 先把 `ZDOTDIR` 交还给用户目录，再 source 真正的 `~/.zshrc`，所以 oh-my-zsh、powerlevel10k、`~/.myprofile/*` 等全部照常加载；差异只有一条：emacs keymap 的 `^[` 绑定到隐藏 drawer 的 widget，并在每次 `precmd` 重新应用一次（防止插件重置键位）。widget 通过 `gdbus` 调用 controller 的 `HideInstance`，controller 校验 instance 是否仍对应活动 drawer，再触发 KWin 注册的无按键 `Hide Ghostty Dropdown` 快捷键。

vim 等程序占用终端时 ZLE 不在前台，Esc 根本不会经过这个 widget。vi 模式的用户不受影响：绑定只写进 emacs keymap，`vicmd`/`viins` 的 Esc 保持原义。

Ghostty 内建的 `escape=end_search` 带 `performable` 属性，没有搜索进行中时不会消费 Esc（源码 `src/Surface.zig`：只有搜索真的被结束才视为 performed），所以实例配置必须用 `config-file` 引用而不是拍平——否则这条绑定会变成无条件消费 Esc，widget 与 vim 都拿不到按键。

## 操作

依赖：Ghostty、KDE Plasma 6 Wayland、systemd user manager、Python 3 + PyGObject、zsh、`gdbus`。

```bash
./install.sh apply
./install.sh status
./install.sh rollback
```

`apply` 首次修改前会把同名文件、KWin 配置键以及 controller 的启用和运行状态保存到 `~/.local/state/ghostty-pd-drawer/pre-shell-migration-v2/`。重复 apply 不覆盖快照。`rollback` 恢复这份真实状态（包括被删除的 `dropdown.css` 与 zsh overlay），并把已使用的快照保留到 `history/`。

从旧 tmux 版本升级时，apply 不会终止仍在运行的旧 drawer；关闭它一次后，新的 `Meta+\`` 路径才会进入无 tmux 的实例级配置流程。

## 支持范围

安装脚本不调用发行版包管理器，可用于采用常规 XDG 目录的 Fedora、Ubuntu、Debian、Arch 等 Linux 系统。窗口管理依赖 KWin 6 脚本 API；GNOME、X11 和其他合成器不在支持范围内。Prompt 上的 `Esc` 依赖 zsh；其它 shell 下 `Esc` 直接交给程序，其余功能不受影响。
