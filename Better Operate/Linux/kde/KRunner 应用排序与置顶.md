---
title: KRunner 应用排序与置顶
tags: [kde, krunner, desktop-entry]
note_types: Jotting
created: 2026-10-07
updated: 2026-10-07
---

# KRunner 应用排序与置顶

KRunner 没有"收藏/置顶应用"的设置，应用结果的先后完全由 Applications 插件（`ServiceRunner`）自己算的分决定。它算的不是加权求和，而是**命中项的平均分**：四张卡片 Name(100) / 未翻译 Name(75) / GenericName(50) / Keywords(25)，每张命中后给分子加 `110×权重`（前缀命中）+ `100×权重`（完整命中）+ 模糊分×权重，分母按**项数**计（每卡最多 3 项，每多一条命中关键词再加 1 项）。权重只决定项值大小，不决定它占几项——所以 Keywords 权重最小（项值约 2500–2750），一旦命中就会把已经有名字命中的应用的平均分往下拉。

## 量级与规律

| 匹配情况 | 分数（量级） | 结果 |
| --- | --- | --- |
| 只有 Name / 未翻译名命中 | ≈ 5500 | 名字命中者靠前 |
| Name 命中 + keywords 也命中 | 掉到 ≈ 4000 | 被自己的关键词拖后 |
| 只有 keywords 命中（别名搜索） | ≈ 1400–1800 | 能被搜到，但排在名字命中之后 |

实战案例：`koto` 想找 `Kotofox`，却总被 `Kotonoha` 压住。原因是 `kotofox.desktop` 里写了 `Keywords=koto;kotofox;...`，这两条和名字重复的关键词把它从 ≈5504 拉到 ≈4028，而 `kotonoha` 无关键词命中、稳定在 ≈5500。

## 两条纪律

- **keywords 只写名字里没有的别名**（如 `播放器`、`musicfox`）。别名搜索靠它没问题，但它不会让应用排更前；写成本身名字的前缀（`koto` 之于 `Kotofox`）纯属自我稀释。
- **想压过"名字匹配"的对手，只能让 Name 精确等于查询词**：`name == query` 时插件直接给最大 relevance + `CategoryRelevance::Highest`，任何模糊分都越不过去。

## 置顶配方

给需要的查询词建一个精确同名的别名入口，例如 `~/.local/share/applications/koto.desktop`：

```ini
[Desktop Entry]
Type=Application
Name=koto
GenericName=Kotofox
Exec=sh -c '/home/pi/.local/lib/kotofox/kotofox open'
Icon=kotofox
Terminal=false
StartupNotify=false
Categories=AudioVideo;Audio;Player;
```

`Exec` 必须与主体的 `kotofox.desktop` 不同：插件按 `Exec` 字符串去重，相同的话其中一个会被丢弃。该行会显示为 "koto"（副标题 Kotofox），并会作为普通项出现在应用菜单里。

改完 `.desktop` 后 kded 会自动重建 ksycoca、KRunner 自动重载；不生效就手动刷新：

```bash
kbuildsycoca6
systemctl --user restart plasma-krunner.service
```

## 参考

- 打分逻辑：plasma-workspace `runners/services/servicerunner.cpp` 的 `fuzzyScore()` / `makeScores()` / `makeScoreFromList()`（本机 6.7.5，插件文件 `/usr/lib64/qt6/plugins/kf6/krunner/krunner_services.so`）
- 调试日志类别：`org.kde.plasma.runner.services`（模糊匹配细节：`org.kde.plasma.runner.services.bitap`）
