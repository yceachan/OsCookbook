在要求clean workspace 的仓库，使用此命令来暂时藏匿那些工作区 无关改动，便于整理提交历史。

| push                      | 说明                                                         |
| ------------------------- | ------------------------------------------------------------ |
| `git stash [push]`        | 把所有已跟踪文件的修改（已暂存 + 未暂存）推到stash栈，清空本地工作区和暂存区到HEAD状态 |
| `git stash push -u`       | 额外包含未跟踪文件（untracked）                              |
| `git stash push -k`       | stash 未暂存修改，**保留已暂存内容**在工作区和暂存区         |
| `git stash push --staged` | 仅 stash 已暂存内容，保留未暂存修改（Git 2.35+）             |

| pop                         | 说明                                          |
| :-------------------------- | :-------------------------------------------- |
| `git stash apply`           | 恢复最新 stash 到工作区，但**不删除**该 stash |
| `git stash apply stash@{1}` | 恢复指定 stash                                |
| `git stash pop`             | 恢复最新 stash 并**删除**它                   |
| `git stash pop stash@{1}`   | 恢复指定 stash 并删除它                       |

| drop                       | 说明           |
| :------------------------- | :------------- |
| `git stash drop`           | 删除最新 stash |
| `git stash drop stash@{1}` | 删除指定 stash |
| `git stash clear`          | 清空所有 stash |

| show                          | 说明                                     |
| :---------------------------- | :--------------------------------------- |
| `git stash list`              | 列出所有 stash，最新在最上面             |
| `git stash show`              | 显示最新 stash 的摘要（文件列表 + 统计） |
| `git stash show -p`           | 显示最新 stash 的完整补丁                |
| `git stash show stash@{1}`    | 查看指定 stash 的摘要                    |
| `git stash show -p stash@{1}` | 查看指定 stash 的完整补丁                |