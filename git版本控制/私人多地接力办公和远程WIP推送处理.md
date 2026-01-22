# 用户心得

- WIP：work in progress，进行中的工作

**对于WIP推送**，rebase功能天生与 pull（实际是里面的merge功能）天然冲突。因为rebase后两个分支会有差异，如果merge，版本迭代历史上就会出现分支点

![image-20260108012459311](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/image-20260108012459311.png)

故而，对于WIP 高频小幅迭代，在**大型协作项目**中，WIP 只适合 在本地 commit 或推向私人分支。 

在完成整个feature开发后，再rebase压缩本地commit，**向主仓库线性推送 featrue version commit**

## evaluate： 基于soft reset 的工作流

某地进行 多段 WIP commit 后， 完成工作后使用 

`git reset --soft origin/head` 来清除commit 记录，而非rebase到`origin/head`，再commit

- 考虑`origin/head`是WIP的，那就rebase 到本地 和 origin 共同的feature commit 上，再`push --force-with-lease`
- 考虑`origin/head`是一个useful的commit，而此时又额外进行了一些patch 修补希望整合到head上面： 
  - 推送使用`commit --amend` 和`push -fwl` ,fetch使用`fetch` 和`reset --hard origin/head`
  - 推送使用`commit -m wip` 和`push` ;fetch 使用`pull` ，然后择机`rebase`
  - 评估两个方案

# 多地办公与远程 WIP 推送处理指南

在多人协作且需要多地办公（如公司、家里切换）的场景下，Git 的使用核心在于：**如何平衡“随时备份进度”与“保持主干历史整洁”之间的矛盾**。

---

### 1. 核心原则：私有分支策略

*   **原则**：绝对不要在公共分支（如 `main`, `develop`, `release`）上推送 WIP 提交。
*   **做法**：为每个任务创建独立的特性分支（Feature Branch）。在这个分支上，你可以尽情推送任何琐碎的改动，因为这不会影响其他同事。

---

### 2. 关键操作：安全强制推送；fetch & reset --hard

当你通过多台设备（电脑 A 和 电脑 B）操作同一个特性分支，并频繁使用 `rebase` 整理历史时，会面临本地与远程历史不一致的问题。

#### A. 强制推送安全指令：`--force-with-lease`
当你本地通过 `rebase` 合并了多个 WIP 提交后，本地的 Commit ID 会发生变化，此时直接 `push` 会被拒绝。
*   **不要使用**：`git push --force`（这会盲目覆盖远程，可能冲掉你在另一台机器上刚刚推送但还没拉取的内容）。
*   **推荐使用**：`git push --force-with-lease`。
    *   **原理**：它会检查远程分支的指向是否和你本地记录的远程分支指向一致。如果一致，说明没人动过远程，可以安全覆盖；如果不一致，说明你在另一台机器上推了新东西，它会报错提醒你。

#### B. 异地接力工作流（实战演练）

假设你正在开发特性 `feature-x`：

**第一步：在公司电脑 A 操作**
1.  写了一半代码：`git commit -m "WIP: 登录模块逻辑"`。
2.  下班前推送：`git push origin feature-x`。

**第二步：回到家里电脑 B 操作**
1.  第一次拉取：`git pull origin feature-x`。
2.  继续开发并提交：`git commit -m "WIP: 修复了 A 机器遗留的 bug"`。
3.  **关键步骤（本地整理）**：在准备结束前，将两个 WIP 合并。
    *   `git rebase -i HEAD~2`（将两个 WIP 标记为 `fixup` 或 `squash`）。
4.  **推送到远程**：此时历史已变，必须强推。
    *   `git push origin feature-x --force-with-lease`。

**第三步：第二天回到公司电脑 A**
1.  **警告**：此时电脑 A 的本地 `feature-x` 历史与远程（家里整理后的）已经完全不同。
2.  **绝对不要 pull**：`pull` 会尝试合并产生复杂的冲突和重复的提交。
3.  **正确做法（强制重置）**：
    *   `git fetch origin`（获取远程最新状态）。
    *   `git reset --hard origin/feature-x`（将本地分支强行指向远程分支，放弃本地旧的历史）。
    *   @notice:这两行指令显示了fetch的逻辑：获得远程主机的仓库状态到`.git`,**但暂不更新本地仓库的分支版本**。
        **此时，可以用reset指令把本地分支的head指针指向远程分支，并使用--hard参数更新本地工作区**
4.  继续当天的开发。

---

### 3. 协作边界：何时不能再 Rebase？

*   **私有分支**：可以随便 Rebase。
*   **共享特性分支**（两人合作的分支）：协商 Rebase。**其中一人 Rebase 并强推后，另一人必须立即使用 `git reset --hard` 同步。**
*   **公共主分支**（main/develop）：**严禁 Rebase**。一旦代码合并入主分支并被大家拉取，历史就成了“法律”，只能通过 `merge` 或 `revert` 来处理。

---

### 4. 存储优化：清理变基留下的“碎片”

频繁的 `rebase` 和 `reset --hard` 会在本地产生大量不再被引用的孤立对象，这会增加 `.git` 的体积。

*   **自动清理**：`git gc --auto`（Git 通常会在你操作时后台自动触发）。
*   **手动极致压缩**：
    ```bash
    git gc --aggressive --prune=now
    ```
    这会立即清除所有悬空的 commit 对象并重新打包索引，确保你的磁盘占用最小。

---

### 5. 总结口诀
*   **异地办公用私分**（特性分支）。
*   **下班备份多 WIP**。
*   **准备并入先变基**（rebase -i）。
*   **强推带上 lease 锁**（--force-with-lease）。
*   **切换设备先重置**（reset --hard）。
