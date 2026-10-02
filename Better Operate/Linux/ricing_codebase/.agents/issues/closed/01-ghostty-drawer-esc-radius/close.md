# 结论

2026-09-20 关闭。四项需求全部实现，已由用户在真实桌面（eDP 屏）确认；`apply` / `status` / `rollback` 三条生命周期均跑通。设计与依据见 [design.md](design.md)，需求原文见 [issue.md](issue.md)。

## 四条需求的结果

| # | 需求 | 结果 | 证据 |
| --- | --- | --- | --- |
| 1 | 圆角与主终端统一 | 改为共用 `window-decoration = client`，圆角由 Breeze GTK 主题的 `window.csd` 提供，`dropdown.css` 已删除 | 2× 截图逐像素扫描，两边圆弧轮廓都是 `x + y ≈ 16 px` |
| 2 | Esc 只在提示符激活 | Ghostty 不再消费 Esc；Esc 改由 drawer shell 的 ZLE widget 绑定为「隐藏 drawer」，只在提示符下生效 | 隔离 zsh 中 `bindkey -M emacs '^['` 从 `undefined-key` 变为 `_ghostty_pd_drawer_hide`；vim 正常收到 Esc |
| 3 | 迁移后释放 Esc | 迁移时删除运行态 `current`，controller 随即拒绝隐藏请求，widget 成为空操作 | 迁移后同样调用返回 `HideFailed: This shell does not own the active drawer` |
| 4 | 迁移尺寸跟随主终端配置 | 按主终端 `window-width = 100` / `window-height = 32`，用 drawer PTY 标定单元格后套用 Ghostty 公式 | controller 返回 `(988, 647)`，实测窗口 988 × 646.667 居中在 eDP，网格 100 × 30，进程号未变 |

## 交付内容

`ghostty_PD_drawer/`：

| 文件 | 变化 |
| --- | --- |
| `src/ghostty/dropdown.ghostty.in` | 只保留 drawer 专属项：无标题栏、`window-decoration = client`、`window-width/height = 0`；删掉写死外观与 `escape=toggle_maximize` |
| `src/ghostty/dropdown.css` | 删除（圆角改由 GTK 主题提供），快照中保留以支持 rollback |
| `src/zsh/drawer-zshrc.in` | 新增：ZDOTDIR overlay，把提示符下的 Esc 绑定到隐藏 widget |
| `src/systemd/ghostty-dropdown@.service.in` | 新增实例级 unit：`ZDOTDIR`、`GHOSTTY_PD_DRAWER_INSTANCE`、实例配置文件、`ExecReload = SIGUSR2` |
| `src/systemd/ghostty-dropdown.service.in` | 删除（被实例级 unit 取代） |
| `src/libexec/ghostty-dropdown-controller.py` | 实例配置改为 `config-file` 引用式；PTY 标定单元格；`Promote(i i) → (i i)`；journal 日志；清理陈旧 `current` |
| `src/kwin/ghostty-dropdown/contents/code/main.js` | 迁移尺寸改用 controller 返回值并 `Math.round`；去掉过严的焦点守卫；新增无按键 `Hide Ghostty Dropdown`；重载不打扰已有 drawer |
| `install.sh` | 安装与回滚上述内容，首次修改前快照到 `~/.local/state/ghostty-pd-drawer/pre-shell-migration-v2/` |
| `README.md` | 行为、圆角来源、prompt 上的 Esc、迁移尺寸、操作与支持范围 |

用户可见行为：`Meta+\`` 开关 drawer，提示符下 `Esc` 隐藏，`Meta+F` 原地迁移为普通窗口（同一进程、PTY、session 与 scrollback），迁移后 `Esc` 完全回归程序。

## 验证方式

- 生命周期：`./install.sh apply` → `status` → `rollback` → `apply`，全部通过；快照保留在 `~/.local/state/ghostty-pd-drawer/`，回滚过的快照进 `history/`。
- 键位：overlay 与普通 `zsh -i` 的 PATH、alias 完全一致（hash 相同），差异只有 Esc 绑定。
- 窗口：`Meta+F` 前后对比进程号、网格、`noBorder` / `keepAbove` / `skipTaskbar`、frame 几何与所在屏。
- 圆角：2× 逻辑像素截图逐行扫描轮廓。
- 端到端实测数据见 [design.md §7](design.md)。

## 遗留与边界

1. drawer 跟随当前聚焦屏：游戏占焦点时按 `Meta+\`` 会把 drawer 放到游戏屏。如需固定在某一屏，需要另做设计。
2. 旧 tmux 版本升级：`apply` 不会终止仍在运行的旧 drawer；关闭它一次后，新的 `Meta+\`` 路径才进入无 tmux 的实例级配置流程。
3. 提示符上的 `Esc` 依赖 zsh；其它 shell 下 Esc 直接交给程序，其余功能不受影响。
4. 窗口管理依赖 KWin 6 脚本 API；GNOME、X11 和其他合成器不在支持范围。
