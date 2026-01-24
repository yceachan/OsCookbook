`git-filter-repo` 是目前 Git 官方社区**最推荐**的历史重写工具。

它被设计用来取代那个极其难用、缓慢且充满陷阱的 `git filter-branch`，同时也比 `BFG Repo-Cleaner` 更强大、更通用。

以下是关于它的详细介绍、安装方法及针对你场景的实战指南。

::: note

不要再狼狈删库重建了，好么？

:::

------

### 1. 为什么它是最佳选择？

- **速度极快**：它使用 Python 编写，直接操作 Git 的底层对象，处理速度比 `filter-branch` 快数量级。
- **安全性高**：它在执行前会自动进行大量的检查（比如要求仓库是干净的），并且默认不会破坏你当前的引用，除非你明确要求。
- **彻底性**：它不仅能删除文件，还能自动清理相关的 Tag、重写 Commit Message、甚至调整作者邮箱等元数据。
- **单文件脚本**：虽然它是一个库，但它本身就是一个单独的 Python 脚本，极易分发。

------

### 2. 安装方法

前提：你需要安装 Python (3.5+)。

**Windows / Mac / Linux 通用：**

Bash

```
pip install git-filter-repo
```

安装完成后，你可以通过 `git filter-repo --version` 检查是否成功。注意，安装后它是作为一个 Git 子命令存在的，所以你在命令行直接敲 `git filter-repo` 即可调用。

------

### 3. ⚠️ 极其重要的准备工作

在使用此工具之前，请务必遵守以下**铁律**，因为**历史重写是不可逆的**（Commit ID 会全部改变）：

1. **不要在你的主工作目录操作**：另外 Clone 一个全新的副本专门用来清洗。
2. **备份**：确保你有一份原始代码的完整压缩包或备份。
3. **通知团队**：如果你推送到远程，所有队友都需要删除旧的本地仓库重新 Clone，否则会发生严重的合并冲突。

------

### 4. 实战场景：针对你的需求

#### 场景 A：彻底删除误传的大文件（如你的 .rar）

这是最常用的功能。假设你要从所有历史记录中彻底抹除 `1307_keyboard_base/doc/` 目录和所有 `.rar` 文件。

**步骤：**

1. **分析仓库（可选）**：

   查看仓库里到底什么文件占空间最大。

   Bash

   ```
   git filter-repo --analyze
   # 这会在 .git/filter-repo/analysis/ 目录下生成一份详细报告（txt文件），告诉你哪些文件最大。
   ```

2. **执行删除**：

   使用 `--path` 指定路径，并配合 `--invert-paths`（反选，即“除了这些路径其他的都保留” = 删除这些路径）。

   Bash

   ```
   # 彻底删除特定的目录
   git filter-repo --path 1307_keyboard_base/doc/ --invert-paths
   
   # 如果要同时删除所有 rar 文件 (支持 glob 模式)
   git filter-repo --path-glob '*.rar' --invert-paths
   ```

   *命令执行只需几秒钟。完成后，Git 历史中就不再有这些文件的踪影了。*

#### 场景 B：只保留某个子文件夹（拆分仓库）

假设你的仓库很大，你只想把 `TestWork` 目录独立出来变成一个新的 Git 仓库，其他都不要。

Bash

```
git filter-repo --path TestWork/
# 注意：这里没有 --invert-paths，意思是“只保留”这个路径。
```

这会将 `TestWork/` 提升为根目录，历史记录只保留与该目录相关的提交。

#### 场景 C：批量修改文件内容（如移除密码）

虽然 BFG 做这个也很方便，但 `git-filter-repo` 也可以。

你需要创建一个替换规则文件 `replace.txt`：

Plaintext

```
password123==>REMOVED_PASS
api_key_xyz==>REMOVED_KEY
```

然后运行：

Bash

```
git filter-repo --replace-text replace.txt
```

------

### 5. 清理后的收尾工作

执行完 `git filter-repo` 后，你会发现本地的 `.git` 目录体积并没有立刻变小，甚至可能因为备份机制变大了。

**最终瘦身步骤：**

1. **强制推送到远程**（危险操作，确保你是仓库管理员且队友知情）：

   Bash

   ```
   git push --force --all
   git push --force --tags
   ```

   *注意：git-filter-repo 为了安全，默认会移除远程仓库的 `origin` 关联。你需要手动加回来：`git remote add origin <url>`*

2. **本地垃圾回收**（如果你不想重新 Clone）：

   `git-filter-repo` 通常会自动处理引用日志，但你可以手动强制回收空间：

   Bash

   ```
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   ```

### 总结

对于你之前提到的误传 `.rar` 和测试目录，流程如下：

1. `pip install git-filter-repo`
2. `git clone <你的仓库URL> clean-repo`
3. `cd clean-repo`
4. `git filter-repo --path-glob '*.rar' --invert-paths`
5. 检查目录，确认干净。
6. `git remote add origin <你的仓库URL>`
7. `git push --force --all`
8. 通知所有队友：“历史已清洗，请重新 Clone 仓库。”