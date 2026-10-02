# 01 · ghostty drawer：圆角、Esc 语义与迁移尺寸

状态：2026-09-20 关闭。设计与依据见 [design.md](design.md)，结论见 [close.md](close.md)。

涉及组件：`ghostty_PD_drawer/`（Ghostty 实例配置、KWin 脚本、systemd unit、zsh overlay、controller、install.sh）。

## 用户提出的问题（原文）

> 关于 ghostty drawer
>
> 1. 圆角请跟主终端配置统一
> 2. esc 后台化 pty 的快捷键，应该只在 shell prompt 上激活，现在他始终激活，我 vim 都退不出编辑模式了
> 3. 他 win+f 迁移出的新终端，esc 既不能最小化，也没有释放给 app；特性应该是迁移到新终端后，释放 esc 快捷键
> 4. 然后是窗口 size，现在是中心对齐正方形，把 size 改成主终端的那个配置吧
>
> 补充：在 edp 屏测试，别来 hdmi 屏烦我，我在打游戏。

## 问题拆解

四条需求表面各不相干，病灶是同一个：drawer 复刻了主终端的配置项，两份配置各自演化后必然漂移。

| # | 现象 | 需求 |
| --- | --- | --- |
| 1 | 圆角由 drawer 自己写死的 CSS 提供，来源与主终端不同 | 与主终端共用同一来源，改主题两边一起变 |
| 2 | Ghostty 键绑定里的 `escape=…` 无法判断提示符，始终消费按键 | Esc 只在 shell 提示符下触发隐藏，其它场合原样交给程序 |
| 3 | 迁移成普通窗口后，Esc 仍被 drawer 逻辑接管 | 迁移即释放 Esc，回归普通终端语义 |
| 4 | 迁移后的窗口是「中心对齐正方形」，与主终端尺寸配置无关 | 尺寸按主终端 `window-width` / `window-height` 计算 |

## 约束

- 验证环境限定 eDP 屏（用户当时在 HDMI 屏上打游戏），不得在 HDMI 屏上做窗口操作。
- 不回退既有行为：`Meta+\`` 开关，`Meta+F` 原地迁移且同一个 Ghostty 进程、PTY、shell、前台任务与滚动缓冲区都保留。
- 交付物仍是可 `apply` / `status` / `rollback` 的安装脚本，不能只留本机手工改动。

## 验收标准

1. drawer 与主终端的圆角轮廓逐像素一致，且两边来源同一条规则。
2. 提示符下按 Esc 隐藏 drawer；vim、less、REPL 等程序中 Esc 原样送达程序，vim 能正常退出插入模式。
3. `Meta+F` 迁移出的窗口里 Esc 不被任何 drawer 逻辑截获。
4. 迁移后的窗口尺寸等于主终端配置 `window-width = 100` / `window-height = 32` 对应的像素尺寸，并落在 drawer 原本所在的屏。
