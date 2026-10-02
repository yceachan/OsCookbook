# 设计

01 · ghostty drawer 的圆角、Esc 语义与迁移尺寸。需求原文与验收标准见 [issue.md](issue.md)，最终结论见 [close.md](close.md)。

## 0. 设计原则

四条需求分属外观、键位、迁移、几何四件事，但根因一致：drawer 把主终端的配置项抄了第二份，两份配置各自演化后必然漂移。所以这里不逐个调数值，而是把每一项都改回与主终端共用同一条代码路径或同一个事实来源。

| 项 | 之前的来源 | 之后的来源 |
| --- | --- | --- |
| 圆角 | drawer 写死的 `dropdown.css` | 与主终端共用 GTK 主题的 `window.csd` 规则 |
| Esc 归属 | Ghostty 键绑定（判断不了提示符） | drawer shell 的 ZLE widget（唯一能判断提示符的地方） |
| 迁移后的 Esc | 键绑定无条件生效 | controller 用运行态状态拒绝非活动 drawer 的请求 |
| 迁移尺寸 | KWin 侧写死的居中几何 | 主终端配置 + Ghostty 自己的尺寸公式 |

第二条推出一个结构性选择：drawer 的 shell 必须是可被自己改写的 shell，于是引入 `ZDOTDIR` overlay 与实例级 systemd unit；第四条推出另一个：窗口尺寸需要在 drawer 的 PTY 里现场标定字体单元格，于是 controller 多了一条读 `TIOCGWINSZ` 的路径。

## 1. 圆角：复用同一条代码路径

主终端的圆角并不来自 Ghostty 配置，而来自 Breeze GTK 主题。`~/.config/ghostty/config.ghostty` 里 `window-decoration = client` 让窗口成为 CSD，GTK4 主题文件 `/usr/share/themes/Breeze/gtk-4.0/gtk.css` 的 `window.csd { border-radius: 5px }` 因此生效（Ghostty 侧见 `src/apprt/gtk/class/window.zig: syncAppearance`：CSD 时加 `csd` 类，SSD 时加 `ssd` + `no-border-radius`）。

drawer 之前用 `window-decoration = none`，再靠 `gtk-custom-css` 写死半径，本身就是第二份来源。设计决策是改回 `window-decoration = client`（保留 `gtk-titlebar = false`、`gtk-titlebar-style = native`、`window-show-tab-bar = never`），两边共用主题规则，`dropdown.css` 随之删除。

实测（2× 逻辑像素截图，取窗口左上角逐行扫描「窗口内容起点」）：

| 窗口 | 圆弧轮廓 | 结论 |
| --- | --- | --- |
| drawer（eDP，窗口 852.7×340 @427,0） | 边界 `x + y ≈ 16 px` | 与主终端一致 |
| 主终端 | 边界 `x + y ≈ 16 px` | 与 drawer 一致 |

## 2. Esc：把判定权放到能判断提示符的地方

### 2.1 为什么不能在 Ghostty 侧完成

Ghostty 无法判断「当前是否在 shell 提示符」：`keybind` 只有 `global:` / `all:` / `unconsumed:` / `performable:` 前缀（见 `src/config/Config.zig` 的 keybind 文档），key table 只能由 keybind 激活，shell integration 没有触发动作的通道；`reset_window_size` 等动作在 GTK 端未实现（`src/apprt/gtk/class/application.zig` 的 unimplemented 列表）。能把 Esc 限制在提示符上的地方只有 shell 自己。

### 2.2 实现：ZDOTDIR overlay

drawer unit 设置 `ZDOTDIR=<overlay>` 与 `GHOSTTY_PD_DRAWER_INSTANCE=%i`。Ghostty 的 zsh integration 会把已有 `ZDOTDIR` 存进 `GHOSTTY_ZSH_ZDOTDIR` 再注入自己的目录，其 `.zshenv` 先还原并 source `$ZDOTDIR/.zshenv`（源码：`src/termio/shell_integration.zig: setupZsh` 与 `/usr/share/ghostty/shell-integration/zsh/.zshenv`），所以 overlay 会被正常读到，随后的 `.zshrc` 也来自 overlay。

overlay 结构：

```text
~/.local/share/ghostty-pd-drawer/zdotdir/
├── .zshenv   -> ~/.zshenv     （符号链接，用户文件行为不变）
├── .zprofile -> ~/.zprofile
├── .zlogin   -> ~/.zlogin
└── .zshrc                      （source 用户 .zshrc 后追加 Esc 绑定）
```

`.zshrc` 先把 `ZDOTDIR` 交还用户目录，再 source 真正的 `~/.zshrc`，然后追加：

```zsh
bindkey -M emacs '^[' _ghostty_pd_drawer_hide     # precmd 每次重新应用
```

`_ghostty_pd_drawer_hide` 只做一件事：`gdbus call ... HideInstance "$GHOSTTY_PD_DRAWER_INSTANCE"`。

只写 emacs keymap 是有意的：vim 等程序占用终端时 ZLE 不在前台，Esc 根本不经过 widget；vi 模式用户的 `vicmd` / `viins` 键位保持原义。

验证：`ZDOTDIR=<overlay> zsh -i` 与普通 `zsh -i` 对比 —— PATH、alias 完全一致（hash 相同），`bindkey -M emacs '^['` 从 `undefined-key` 变为 `_ghostty_pd_drawer_hide`，widget 已注册。

### 2.3 陷阱：拍平配置会丢掉键绑定属性

`Meta+F` 修好之后，用户仍反馈 drawer 里 Esc 有问题，且 controller journal 里没有任何 hide 记录（说明 ZLE widget 从未触发）。

排查过程：

- unit 环境正确（`ZDOTDIR=<overlay>`、`GHOSTTY_ZSH_ZDOTDIR=<overlay>`、`GHOSTTY_PD_DRAWER_INSTANCE=<instance>`），overlay 与 widget 在隔离 zsh 中实测可用。
- 对照源码：Ghostty 内建默认 `escape=end_search` 带 `{ .performable = true }`（`src/config/Config.zig`），而 `end_search` 只在真的结束了一次搜索时才 `performed`（`src/Surface.zig`），所以默认情况下 Esc 不消费、会送到 PTY。
- 但实例配置里写的是 `keybind = escape=end_search`——没有 `performable:` 前缀。controller 用 `ghostty +show-config` 拍平后写回，前缀在拍平过程中丢失，drawer 实际加载的是一条无条件消费 Esc 的绑定，Esc 既到不了 ZLE，也到不了 vim。
- 这也解释了最初第 2 条的现象：当时 drawer 配置里还有 `escape=toggle_maximize`（同样消费按键），删掉它只是落到了同样消费的拍平默认值上。

修法：`write_instance_config` 不再写拍平结果，而是写 `config-file = ` 引用（用户的 `config`、`config.ghostty`，drawer 再追加 `dropdown.ghostty`）；拍平只在 `resolve_config()` 里做，用于读取 `window-width` / `window-padding-*` 等值，不再落盘。Ghostty 支持配置文件里嵌套 `config-file`，键绑定属性因此完整保留。

实测（drawer 热重载后的 journal）：

```text
info: reading configuration file path=/run/user/1000/ghostty-pd-drawer/432679-....ghostty
info: reading configuration file path=/home/pi/.config/ghostty/config
info: reading configuration file path=/home/pi/.config/ghostty/config.ghostty
info: reading configuration file path=/home/pi/.config/ghostty/dropdown.ghostty
systemd: Reloaded ghostty-dropdown@432679-....service
```

顺带发现：Ghostty 自己也会同时加载同目录下的 `config` 与 `config.ghostty`（journal 里有对应 warning），这与 controller 的合并顺序一致。

## 3. 迁移：释放 Esc，并让尺寸跟随主终端

`Meta+F` 沿用原有设计：通过 `ExecReload=SIGUSR2` 热重载实例配置，再撤销 KWin 的无边框、置顶、任务栏隐藏与固定尺寸属性，从而在同一个 Ghostty 进程里把 drawer 变成普通窗口（PTY、shell、前台任务与 scrollback 保留）。本次只改两件事——迁移后 Esc 的归属，以及迁移后的窗口尺寸。

### 3.1 迁移后释放 Esc

controller 的 `HideInstance` 先用运行态文件 `current` 校验 `instance` 是否为活动 drawer：错误 instance 返回 `HideFailed: This shell does not own the active drawer`（实测）。迁移时 `promote_ghostty` 重写配置并 `CURRENT_STATE.unlink()`，此后同样的调用被拒绝，widget 成为空操作，Esc 回到程序手里。

这里没有引入新的「已迁移」标志位，复用已有的运行态文件，避免第二份状态与真实 drawer 生命周期不同步。

### 3.2 迁移尺寸：用 drawer 自己的 PTY 标定单元格

主终端配置是 `window-width = 100`、`window-height = 32`。Ghostty 的窗口尺寸公式（`src/apprt/gtk/class/surface.zig: estimateInitialSize`）为 `ceil(格数 × 单元格像素) + padding`，关键是拿到真实单元格尺寸，而不是猜字体度量。

PTY 的 `TIOCGWINSZ` 同时给出网格（cols/rows）与网格区域像素（`ws_xpixel` / `ws_ypixel`，Ghostty 在 `src/termio/Exec.zig` 写入），据此可以从前台进程反查 drawer 的 PTY（`terminal_grid()` 沿 `/proc/<pid>/fd/0` 遍历子进程）：

- 单元格宽 = `(窗口宽 − 左右 padding) / cols`（窗口宽里最多多出一个未使用的单元格）；
- 单元格高 = 单元格宽 × `(ws_ypixel / rows) / (ws_xpixel / cols)`，纵横比来自 PTY，是精确值，不受标题栏与小数缩放影响。

单元格高特意不取 `(窗口高 − padding) / rows`：drawer 的 frame 高由 KWin 规则给定，与真实网格行数不成整数关系，会高出一行。

用主终端交叉验证公式（主终端 86×50，frame 853.3×1021.3，ws 1642×1886）：

```text
单元格 = 9.643 × 19.051 逻辑像素      隐含 buffer scale ≈ 1.98
50 × 19.051 + 24 + 标题栏 44.8 = 1021.3  ← 与实测 frame 高度吻合
```

对 drawer 取实测值（frame 852.7×340，网格 86×16，ws 1642×616）：单元格 `9.640 × 19.438`，于是 `ceil(100 × 9.640) + 24 = 988`、`ceil(32 × 19.438) + 24 = 647`，controller 返回 `(988, 647)`。若改用 frame 高直接除行数会得到 656，正好多一行。

KWin 脚本拿到 `(w, h)` 后居中放置；`(0, 0)` 表示无法推导（读不到 PTY 或配置缺项），回退到原来的居中几何。

## 4. KWin 侧接口

新增无按键快捷键 `Hide Ghostty Dropdown`（语义上只隐藏，不会像 `Toggle` 那样在找不到 drawer 时新开一个）。实测 `KGlobalAccel.Component.invokeShortcut` 能调用无键快捷键，controller 因此无需知道窗口状态。

`Promote` 签名变为 `Promote(i i) → (i i)`。用临时 D-Bus 服务验证过 KWin `callDBus` 的多返回值回调可用（两个整数被正确解析成 `Pair`）。

### 4.1 Meta+F 一度失效的两个根因

有两个独立问题，先后暴露：

1. **守卫过严**（旧行为，影响「焦点被全屏程序占着」或「drawer 已被 Esc 隐藏」的场景）。调试脚本实测：`guard: called managedWindow=com.mitchellh.ghostty.dropdown hidden=false active=cs2` → `guard: returned early`。旧实现要求 `workspace.activeWindow === window`，全屏游戏会长期占着焦点，drawer 拿不到 keyboard focus，Meta+F 就静默返回；已用 `Esc` 隐藏时另有一个 `dropdownHidden` 前提。两者都去掉：系统里只可能有一个 drawer（`managedWindow`），快捷键本身就是明确的用户意图。

2. **D-Bus 入参类型静默失败**（真正的「按键没反应」）。新加的 `Promote(i i) → (i i)` 把 `frameGeometry.width/height` 直接当参数传：小数缩放屏上的 frame 几何是小数（实测 852.667），而 KWin `callDBus` 把小数当作 D-Bus `d` 发向 `i` 参数时会静默丢包（既不报错也不回调）。用临时 D-Bus 服务做的对照实验：

   ```text
   Ints(rounded)->1969,1108     # Math.round 后成功
   Strs->1969,1108              # 字符串参数成功
   Ints(double)->（无回调）      # 小数参数静默失败
   ```

   修法：KWin 侧一律 `Math.round(...)` 再传；controller 保持 `i` 签名。`Toggle` 之所以一直正常，是因为它没有入参。

### 4.2 脚本重载不打扰已有 drawer

`configureNewWindow` 增加 `reveal` 参数：`windowAdded`（新 drawer）照旧显形并激活；`classifyExistingWindow`（apply 或 Plasma 重载脚本后接管已有窗口）只接管内部状态，用 `window.opacity === 0` 还原 `dropdownHidden`，不再把已隐藏的 drawer 拽到当前聚焦屏。

## 5. controller 可观测性与陈旧状态

- 日志接入 journal（`logging.basicConfig`），`handle_method_call` 的外层兜底会 `log.exception`，不再出现「D-Bus 调用失败但没人知道」。
- `reload_ghostty` 发现 `current` 指向的实例配置已不存在（drawer 被关闭但状态文件残留）时，删除陈旧的 `current` 再报错，避免之后 `IsCurrent` 把新窗口误判为已迁移。

这两项不是需求的一部分，而是本次排查两次卡在「看不到现场」之后补的：上述 Esc 与 Meta+F 的问题都靠日志和无回调现象才定位到。

## 6. 附带发现：drawer 的尺寸被主终端配置抢

drawer 之前继承了主终端的 `window-width = 100` / `window-height = 32`，Ghostty 的初始窗口尺寸会与 KWin 窗口规则抢尺寸，导致规则宽度实际不生效（实测旧 drawer 网格 100 列 ≈ 977 px，而规则写的是 853）。

drawer 配置显式写入 `window-width = 0` / `window-height = 0`（Ghostty 视为未设置，见 `Surface.zig: recomputeInitialSize` 的 `<= 0` 判断）后，规则重新生效：实测 frame 852.7×340 = eDP 工作区的一半宽、三分之一高。这也是第 3.2 节「迁移尺寸」必须重新标定单元格、不能直接复用 KWin 规则几何的原因。

## 7. 端到端实测（修复后）

在 eDP 上对真实 drawer（ghostty pid 431792，网格 86×16，ws 1642×616）走完整 `Meta+F` 路径：

```text
controller journal: INFO promoted drawer, frame 853x340 -> (988, 647)
迁移后窗口:         class com.mitchellh.ghostty.dropdown, (359, 187), 988 × 646.667
                    noBorder=false keepAbove=false skipTaskbar=false
同一进程:           431792（没有换进程，session / scrollback 保留）
迁移后网格:         100 列 × 30 行（标签栏+标题栏占掉约两行，与主终端行为一致）
```

尺寸 988×647 与用 drawer 自身 PTY 独立推导的值一致，居中位置也正好是 eDP 工作区减去目标尺寸的一半。
