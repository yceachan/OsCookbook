## .gitignore

**1.递归地配置gitignore**

在一个仓库中可以有多个.gitignore，其作用域为当前目录
|.gitignore
|dir1
|--.gitignore
|--subdir
|dir2

**2.忽略文件夹、通配符**

```
#file .gitignore

[./]dir/
```

**3.将已被add/commit的文件 ignored**

```
git rm --cached <file>
git commit -m "rm track"  //!!!!需要提交这个commit应用修改
//edit the .gitignore
//done
```

**4.注释**

\# 开头是注释，会被忽略

## 本地版本控制技巧

* 将本次修改 追加到上次 commit 

  `git commit --amend`

* 合并若干次commit 为一个（压缩版本记录，减少不必要的快照）

  `git rebase -i <commit id>`

  使用git的变基特性。 -i 功能提供一个交互性的vim编辑窗口，来对各条commit操作

  将这些commit 改为drop，就会删除记录

  <img src="https://s2.loli.net/2024/09/12/DrCHwnuqg61c7Az.png" alt="image-20240912191601726" style="zoom:67%;" />

*  --orphan ：重建branch，删除所有commit

  ```
  git checkout --orphan tmp
  ```
  

--orphan <new-branch>

Create a new unborn branch, named `<new-branch>`, started from `<start-point>` and switch to it. The first commit made on this new branch will have no parents and it will be the root of a new history totally disconnected from all the other branches and commits.

The index and the working tree are adjusted as if you had previously run `git checkout <start-point>`. This allows you to start a new history that records a set of paths similar to `<start-point>` by easily running `git commit -a` to make the root commit.

This can be useful when you want to publish the tree from a commit without exposing its full history. You might want to do this to publish an open source branch of a project whose current tree is "clean", but whose full history contains proprietary or otherwise encumbered bits of code.

If you want to start a disconnected history that records a set of paths that is totally different from the one of `<start-point>`, then you should clear the index and the working tree right after creating the orphan branch by running `git rm -rf .` from the top level of the working tree. Afterwards you will be ready to prepare your new files, repopulating the working tree, by copying them from elsewhere, extracting a tarball, etc.

## 远程版本控制与冲突管理

1. **pull冲突 ：refusing to merge unrelated histories**

    两个仓库拥有不同的开始点（unrelated histories），这意味着 `Git` 无法找到一个共同的祖先节点来执行常规的合并操作 

    解决方案：`git pull --allow-unrelated-histories`

    `fatal: refusing to merge unrelated histories` 这个错误提醒我们在合并分支时应当谨慎行事，确保理解并尊重项目的历史演化路径。通过采取适当的解决策略，我们可以既保持 `Git` 仓库的清晰结构，又能满足项目整合的需求。

2. **git psuh 命令**

    ```
     git push [remote host] [<local branch> : <remote branch>]
     
     git push gt/*remote host*/  main/*local branch*/ 
    ```

3. **git push 参数**

    --branches (--all)

    Push all branches (i.e. refs under `refs/heads/`); cannot be used with other <refspec>.

    **--prune**

    **Remove remote branches that don’t have a local counterpart. For example a remote branch `tmp` will be removed if a local branch with the same name doesn’t exist any more. This also respects refspecs, e.g. `git push --prune remote refs/heads/*:refs/tmp/*` would make sure that remote `refs/tmp/foo` will be removed if `refs/heads/foo` doesn’t exist.**

    可以删除远程不必要的branch

    

    --mirror

    Instead of naming each ref to push, specifies that all refs under `refs/` (which includes but is not limited to `refs/heads/`, `refs/remotes/`, and `refs/tags/`) be mirrored to the remote repository. Newly created local refs will be pushed to the remote end, locally updated refs will be force updated on the remote end, and deleted refs will be removed from the remote end. This is the default if the configuration option `remote.<remote>.mirror` is set.

    镜像地将本地仓库push 到远程，这将覆盖远程所有commit和branch

    -d --delete
    
    All listed refs are deleted from the remote repository. This is the same as prefixing all refs with a colon.

## git stash （存储）

- 发现有一个类是多余的，想删掉它又担心以后需要查看它的代码，想保存它但又不想增加一个脏的提交。这时就可以考虑`git stash`。
- 使用git的时候，我们往往使用分支（branch）解决任务切换问题，例如，我们往往会建一个自己的分支去修改和调试代码, 如果别人或者自己发现原有的分支上有个不得不修改的bug，我们往往会把完成一半的代码`commit`提交到本地仓库，然后切换分支去修改bug，改好之后再切换回来。这样的话往往log上会有大量不必要的记录。其实如果我们不想提交完成一半或者不完善的代码，但是却不得不去修改一个紧急Bug，那么使用`git stash`就可以将你当前未提交到本地（和服务器）的代码推入到Git的栈中，这时候你的工作区间和上一次提交的内容是完全一样的，所以你可以放心的修Bug，等到修完Bug，提交到服务器上后，再使用`git stash apply`将以前一半的工作应用回来。
- 经常有这样的事情发生，当你正在进行项目中某一部分的工作，里面的东西处于一个比较杂乱的状态，而你想转到其他分支上进行一些工作。问题是，你不想提交进行了一半的工作，否则以后你无法回到这个工作点。解决这个问题的办法就是`git stash`命令。储藏(stash)可以获取你工作目录的中间状态——也就是你修改过的被追踪的文件和暂存的变更——并将它保存到一个未完结变更的堆栈中，随时可以重新应用。



`git stash`会把所有未提交的修改（包括暂存的和非暂存的）都保存起来，用于后续恢复当前工作目录。
比如下面的中间状态，通过`git stash`命令推送一个新的储藏，当前的工作目录就干净了。stash是本地的，不会通过`git push`命令上传到git server上。



可以通过`git stash pop`命令恢复之前缓存的工作目录，这个指令将缓存堆栈中的第一个stash删除，并将对应修改应用到当前的工作目录下。



你也可以使用`git stash apply`命令，将缓存堆栈中的stash多次应用到工作目录中，但并不删除stash拷贝。命令输出如下：



可以使用`git stash drop`命令，后面可以跟着stash名字

或者使用`git stash clear`命令，删除所有缓存的stash。

# vscode Parctice

| **VSCode 操作项**                          | **功能描述**                               | **对应 Git 命令**                 | **使用场景**                   |
| :----------------------------------------- | :----------------------------------------- | :-------------------------------- | :----------------------------- |
| **暂存更改 (Stage Changes)**               | 将选中文件加入暂存区                       | `git add <file>`                  | 准备提交部分文件               |
| **暂存所有更改 (Stage All Changes)**       | 将所有修改/新增文件加入暂存区              | `git add .` 或 `git add -A`       | 准备提交全部改动               |
| **取消暂存 (Unstage)**                     | 将已暂存文件移回工作区                     | `git reset HEAD <file>`           | 撤销误暂存的文件               |
| **放弃更改 (Discard Changes)**             | **永久丢弃**工作区文件的修改（不可恢复！） | `git checkout -- <file>`          | 撤销未暂存的本地修改           |
| **放弃所有更改 (Discard All Changes)**     | 丢弃所有未暂存的修改                       | `git checkout -- .`               | 彻底还原工作区                 |
| **恢复所选范围 (Discard Changes in Line)** | 丢弃选中代码行的修改（仅限未暂存部分）     | `git checkout -- <file>` + 行范围 | 局部撤销代码块                 |
| **打开文件 (Open File)**                   | 在编辑器中打开文件                         | -                                 | 查看完整文件内容               |
| **查看更改 (View Changes)**                | 打开 Diff 对比视图                         | `git diff <file>`                 | 逐行检查代码变动               |
| **还原文件 (Revert File)**                 | 用最新版本覆盖工作区文件（等价于放弃更改） | `git restore <file>`              | 快速回退单个文件到上次提交状态 |
| **删除文件 (Delete File)**                 | 从工作区和 Git 索引中删除文件              | `git rm <file>`                   | 移除不再需要的版本控制文件     |
| **重命名文件 (Rename File)**               | 修改文件名并保留 Git 历史记录              | `git mv <old> <new>`              | 文件重构时保持追踪连续性       |

## stash

| **VSCode 操作项**                | **功能描述**                             | **对应 Git 命令**             | **使用场景**                         |
| :------------------------------- | :--------------------------------------- | :---------------------------- | :----------------------------------- |
| **存储 (Stash)**                 | 将**未提交的修改**（包括暂存区）临时保存 | `git stash push -m "备注"`    | 紧急切换分支时保留当前工作进度       |
| **存储(包含未跟踪文件)**         | 额外保存**新增的未跟踪文件**             | `git stash push -u -m "备注"` | 需要临时保存所有改动（含未跟踪文件） |
| **应用最新存储 (Apply Stash)**   | 恢复最新存储的修改（**不删除**存储记录） | `git stash apply stash@{0}`   | 恢复最近一次存储的修改               |
| **弹出最新存储 (Pop Stash)**     | 恢复最新存储并**删除**该存储记录         | `git stash pop stash@{0}`     | 恢复后不再需要该存储内容时           |
| **查看存储 (View Stash)**        | 显示存储内容的差异对比                   | `git stash show -p stash@{n}` | 检查存储的具体修改内容               |
| **删除存储 (Delete Stash)**      | 永久移除指定存储记录                     | `git stash drop stash@{n}`    | 清理无用存储                         |
| **全部存储 (Stash All)**         | 存储所有已修改和暂存的文件               | `git stash push --all`        | 快速保存整个工作区状态               |
| **应用存储... (Apply Stash...)** | 从存储列表中选择特定存储进行恢复         | `git stash apply stash@{n}`   | 恢复非最新的历史存储                 |
| **弹出存储... (Pop Stash...)**   | 选择特定存储恢复并删除                   | `git stash pop stash@{n}`     | 精确恢复并清理指定存储               |

## revert

常用于覆盖已经push的commit，生成与参数commit 相反的工作区改动并commit。

此时本地版本领先远程，可以安全地push到远程，并与其他协作者的push不存在版本竞争冲突。

执行 `git revert C` 后：

- 提交 C 的修改会被反向应用（例如 C 添加了代码，revert 则删除这些代码）
- 生成一个新提交 D，内容与 C 前一个版本的状态一致

**关键选项**

| 选项                 | 作用                                                 |
| :------------------- | :--------------------------------------------------- |
| `-n` / `--no-commit` | 撤销更改但不自动提交（可合并多次 revert 到一次提交） |
| `-e` / `--edit`      | 编辑提交信息（默认行为）                             |
| `--no-edit`          | 使用自动生成的提交信息，跳过编辑                     |
| `-m 1`               | 撤销合并提交时指定主分支方向（解决冲突用）           |
| `--continue`         | 解决冲突后继续 revert 流程                           |
| `--abort`            | 终止 revert 并恢复操作前状态                         |

>  附  `git push --force-with-lease` 命令。这个命令是 `git push --force` 的安全版本，用于强制推送更新到远程分支，但提供了一层保护机制，避免覆盖其他人的提交。
>
> 检查远程分支是否有领先本地的新提交，若有，则拒绝推送。

