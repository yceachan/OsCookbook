# issues

Issue 驱动的工作区：用户写问题，agent 在同一目录补设计与结论。

```text
.agents/issues/
├── open/<编号>-<slug>/
└── closed/<编号>-<slug>/
```

每个 issue 目录固定三个文件，各写一件事：

| 文件 | 谁写 | 写什么 |
| --- | --- | --- |
| `issue.md` | 用户 | 问题与需求原文、拆解、约束、验收标准。只写「要什么」和「为什么」，不写结论。 |
| `design.md` | agent | 设计：决策、机制、依据（源码路径、实验、实测数据），以及踩过的坑。写给将来要改这块代码的人。 |
| `close.md` | agent | 结论：交付了什么、验证结果、当前状态、遗留与边界。关闭时写，之后是这块工作的唯一状态来源。 |

约定：

- 目录名用两位自增编号加简短英文 slug，例如 `01-ghostty-drawer-esc-radius`。
- 关闭时用 `git mv` 把目录从 `open/` 移到 `closed/`，然后写 `close.md`。
- `issue.md` 与 `design.md` 在关闭前随时可改，关闭后只追加勘误；结论变更改 `close.md`。
