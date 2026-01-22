# git rebase -i 合并提交操作手册及最佳实践

# 一、文档概述

本文档基于实际开发场景（合并 HEAD 与 HEAD~1 两个提交并编辑提交信息），详细说明 `git rebase -i`（交互式变基）的操作流程，并提炼核心最佳实践，帮助规范提交历史整理操作，避免常见风险。

适用场景：需合并连续的本地提交（未推送或仅个人推送的分支）、优化提交信息，保持提交历史整洁可追溯。

# 二、核心操作步骤（以合并 HEAD 与 HEAD~1 为例）

## 2.1 前置条件确认

先通过 `git log` 确认提交历史，明确需合并的提交范围（本文以“合并最近 2 个提交”为例）：

```powershell

# 查看提交历史（Windows PowerShell 执行）
git log --oneline
# 预期输出（示例）：
# d711ccd (HEAD -> main) wip  # 待合并的较新提交（HEAD）
# 1f8e950 work1/9 WIP of AIAgent  # 待合并的较早提交（HEAD~1）
# 1b41abf (origin/main) 更新git 快速迭代 trick 的文档  # 合并基准提交
```

## 2.2 启动交互式变基

指定变基范围为“最近 2 个提交”（`HEAD~2` 表示从 HEAD 往前数 2 个提交的基准点，即合并的两个提交的共同祖先）：

```powershell

git rebase -i HEAD~2
```

执行后会弹出默认编辑器（如 Vim、VS Code），显示提交列表（按“提交时间倒序”排列，

越早提交越靠上， 越新提交越考下， squash 和 fixup 会把下行提交 合并到上一行。

```bash

pick 1f8e950 work1/9 WIP of AIAgent  # HEAD~1（较早提交，合并基准）
pick d711ccd wip                      # HEAD（较新提交，待合并到上一个）
# 以下为 Git 自动生成的注释说明，无需修改
# Commands:
# p, pick <commit> = use commit
# r, reword <commit> = use commit, but edit the commit message
# e, edit <commit> = use commit, but stop for amending
# s, squash <commit> = use commit, but meld into previous commit
# f, fixup <commit> = like "squash", but discard this commit's log message
# ...
```

## 2.3 配置合并操作

将较新提交（上方的 `d711ccd`）的 `pick` 改为 `squash`（缩写 `s`），表示“将该提交合并到前一个提交（`1f8e950`），并保留两个提交的信息，后续编辑合并后的提交信息”：

```bash

pick 1f8e950 work1/9 WIP of AIAgent  # 保留较早提交作为合并基准
squash d711ccd wip                    # 合并较新提交到基准提交
# 注释部分无需修改
```

编辑器操作说明：

- VS Code：直接修改后保存文件并关闭窗口即可；

- Vim：按 `Esc` 键进入命令模式，输入 `:wq` 并回车（保存并退出）。

## 2.4 编辑合并后的提交信息

保存退出后，Git 会自动弹出编辑器，显示两个原始提交的信息，供你编辑合并后的最终提交信息：

```markdown

# 请编辑合并后的提交信息（以 # 开头的行将被忽略，空信息会终止提交）
work1/9 WIP of AIAgent
wip

# 推荐编辑示例（清晰描述合并后的功能/进度）：
feat: AIAgent 开发 WIP（1/9）
- 完成 AIAgent 核心框架搭建
- 补充知识库初始化逻辑
- 实现基础对话交互流程
```

编辑完成后，保存并退出编辑器（操作同步骤 2.3）。

## 2.5 完成变基与验证

若两个提交无代码冲突（连续本地提交大概率无冲突），Git 会完成合并并输出成功信息：

```bash

Successfully rebased and updated refs/heads/main.
```

执行以下命令验证合并结果：

```powershell

git log --oneline
# 预期输出（仅保留 1 个合并后的提交）：
# a789012 (HEAD -> main) feat: AIAgent 开发 WIP（1/9）  # 合并后的新提交
# 1b41abf (origin/main) 更新git 快速迭代 trick 的文档
```

## 2.6 推送合并后的提交（若需同步远程）

由于 `rebase` 修改了本地提交历史（原两个提交被替换为新提交，ID 变化），普通 `git push` 会失败，需使用 `--force-with-lease` 强制推送（比 `--force` 更安全，可避免覆盖他人提交）：

```powershell

git push origin main --force-with-lease
```

若推送失败（提示远程分支有新提交），需先拉取并整合远程修改，再重新推送：

```powershell

git pull --rebase origin main
git push origin main --force-with-lease
```

# 三、冲突处理流程（可选）

若合并过程中出现冲突（如两个提交修改了同一文件的同一行），Git 会暂停变基并提示冲突文件，处理步骤如下：

1. 打开冲突文件，删除 Git 生成的冲突标记（`<<<<<<< HEAD`、`=======`、`>>>>>>> <commit-id>`），保留正确的代码内容；

2. 标记冲突已解决：`git add <冲突文件路径>`（路径可从 `git status` 输出中查看）；

3. 继续变基流程：`git rebase --continue`；

4. 若想放弃合并，回到变基前的状态：`git rebase --abort`。

# 四、核心最佳实践（Best Practice）

## 4.1 变基范围精准选择

- 合并 N 个连续提交时，变基范围建议使用 `HEAD~N`（如合并 2 个提交用 `HEAD~2`），避免手动输入提交 ID 导致范围错误；

- 若需合并非连续提交，需先通过 `git rebase -i` 调整提交顺序（将需合并的提交调整为连续），再执行合并操作，避免代码依赖冲突。

## 4.2 合并操作类型选择

- 需编辑合并后的提交信息：使用 `squash`（缩写 `s`），适合合并相关的 WIP 提交（如本次场景），可整合两个提交的核心信息；

- 无需保留后续提交信息：使用 `fixup`（缩写 `f`），适合合并无意义的临时提交（如“wip”“test”），直接复用前一个提交的信息，效率更高；

- 仅修改单个提交信息：使用 `reword`（缩写 `r`），无需合并提交，直接编辑目标提交的信息。

## 4.3 提交历史修改安全原则

- 仅对「未推送至远程」或「仅个人使用的远程分支」执行 `rebase -i`，禁止修改公共分支（如 `main`、`develop`）的提交历史，否则会导致团队成员历史不一致；

- 变基前建议通过 `git log --oneline` 记录关键提交 ID，若操作失误，可通过 `git reset --hard <原始提交ID>` 回退；

- 强制推送必须使用 `--force-with-lease`，禁止使用 `--force`：`--force-with-lease` 会先检查远程分支是否有他人新增提交，避免盲目覆盖。

## 4.4 提交信息规范

- 合并后的提交信息建议遵循「类型: 描述」格式（如 `feat`/`fix`/`docs`/`style`/`refactor`/`test`/`chore`），清晰区分提交类型；

- 描述部分简洁明了，可通过换行补充关键细节（如实现的功能点、修复的问题），便于后续代码溯源（示例：`feat: AIAgent 开发 WIP（1/9）\n- 核心框架搭建\n- 知识库初始化`）。

## 4.5 编辑器选择建议

若默认编辑器（如 Vim）使用不熟练，可将 Git 默认编辑器改为 VS Code（更直观），执行以下命令配置：

```powershell

git config --global user.editor "code --wait"
```

`--wait` 参数表示 Git 等待编辑器关闭后再继续操作，避免编辑器闪退导致变基中断。

# 五、常见问题与回退方案

## 5.1 变基过程中想放弃操作

执行以下命令，回到变基前的提交状态：

```powershell

git rebase --abort
```

## 5.2 合并后发现提交信息有误

执行以下命令编辑最新提交的信息（仅适用于未推送的提交）：

```powershell

git commit --amend
```

若已推送，需重新强制推送：`git push origin main --force-with-lease`。

## 5.3 变基后推送失败提示“remote contains work that you do not have”

原因：远程分支有他人新增的提交，需先拉取并整合：

```powershell

git pull --rebase origin main  # 拉取远程修改并变基整合
git push origin main --force-with-lease  # 重新推送
```

# 六、总结

`git rebase -i` 是整理本地提交历史的核心工具，通过本文档的步骤可高效合并连续提交并优化提交信息。关键在于遵循“精准选择范围、规范操作类型、保障历史安全”的原则，仅在个人分支或未推送分支上操作，避免影响团队协作。熟练掌握后，可让提交历史清晰反映开发逻辑，提升代码维护效率。
> （注：文档部分内容可能由 AI 生成）