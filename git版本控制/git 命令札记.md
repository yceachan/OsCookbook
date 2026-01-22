> 本札记不对git 基本机制做探讨，仅做工程使用速查手册。

# 远程推送

## push

`git push <远程仓库别名> <本地分支>:<远程分支>`

核心作用：**将「本地某个分支」的提交，推送到「指定远程仓库」的「某个分支」**。

- 远程仓库别名

  `git remote add [远程仓库别名] <远程地址>` 别名可缺省，默认远程主机为`origin`

  ```powershell
  PS C:\Eachan\Workspace> git remote -v
  origin  https://gitee.com/Ea_Chan/workspace.git (fetch)
  origin  https://gitee.com/Ea_Chan/workspace.git (push)
  ```

- <本地分支>:<远程分支>

  - 本地分支init后默认名为 master或main，取决于git版本（2.88前为master，此后为main）。
  - **可通过 `git config --global init.defaultBranch` 自定义新仓库的默认分支；**
  
- `-u`（--set-upstream）：关联本地分支与远程分支 与

  - 首次推送本地分支到远程时，建立「本地分支 ↔ 远程分支」的关联关系；
  - 后续可直接用 `git push`（无需指定远程和分支），Git 会自动推送至关联的远程分支。

## 本地<-->远程分支管理

|         操作描述         |                       Git 命令                        |
| :----------------------: | :---------------------------------------------------: |
|     删除旧的远程分支     |      `git push origin --delete old-branch-name`       |
|      重命名本地分支      |    `git branch -m old-branch-name new-branch-name`    |
|  推送新命名的分支到远程  |           `git push origin new-branch-name`           |
| 设置远程跟踪分支（关联） | `git branch --set-upstream-to=origin/new-branch-name` |
|   更新本地远程分支引用   |              `git fetch --prune origin`               |

| 参数选项            | 核心作用                                    | 语法格式（本地分支→远程分支）                               | 适用场景                                   |
| ------------------- | ------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------ |
| `--set-upstream-to` | 建立 / 修改本地分支到远程分支的关联（推荐） | `git branch --set-upstream-to=<远程>/<远程分支> <本地分支>` | Git 1.8.0+ 版本（2012 年后），当前主流用法 |
| `--set-upstream`    | 旧版关联语法（反向参数顺序）                | `git branch --set-upstream <本地分支> <远程>/<远程分支>`    | 兼容旧版 Git（<1.8.0），现已不推荐         |

# .gitignore

## 基础匹配规则（带开发场景示例）

|   规则格式    |               作用说明                |           示例（嵌入式开发场景）            |                           匹配结果                           |
| :-----------: | :-----------------------------------: | :-----------------------------------------: | :----------------------------------------------------------: |
|   `文件名`    |  忽略当前目录及所有子目录中同名文件   |             `a.out`、`test.log`             |     忽略所有 `a.out`（编译产物）、`test.log`（日志文件）     |
|   `目录名/`   |   忽略指定目录（含子目录所有内容）    |    `.idea/`、`.vscode/`、`__pycache__/`     |            忽略 IDE 配置目录、Python 编译缓存目录            |
| `路径/文件名` |      忽略指定路径下的文件 / 目录      |        `os/driver/*.o`、`mpu/build/`        | 忽略 `os/driver/` 下的所有 `.o` 目标文件、`mpu/build/` 编译目录 |
|      `*`      |  匹配任意字符（不含路径分隔符 `/`）   |              `*.log`、`*.tmp`               |   忽略所有后缀为 `.log`（日志）、`.tmp`（临时文件）的文件    |
|      `?`      |           匹配单个任意字符            |                 `config.?`                  |        忽略 `config.h`、`config.c` 等单个字符后缀文件        |
|     `[]`      |        匹配括号内任意一个字符         |       `file[0-9].txt`、`lib[abc].so`        |              忽略 `file1.txt`、`liba.so` 等文件              |
|   **`**`**    |         **递归匹配多级目录**          |        **`**/build/`、`src/**/*.o`**        | **忽略所有层级的 `build/` 目录、`src/` 下所有子目录的 `.o` 文件** |
|      `!`      | 否定规则（排除前面匹配的文件 / 目录） |     `!main.c`（在 `*.c` 之后）、`!*.h`      | 忽略所有 `.c` 文件，但保留 `main.c`；忽略所有文件但保留 `.h` 头文件 |
|      `#`      |   注释（行首有效，不能跟在规则后）    | `# 忽略编译产物`、`# *.o`（注释后规则失效） |                     无匹配效果，仅作说明                     |

## 查看被忽略的文件

```shell
# 语法：git ls-files --ignored --exclude-standard --others
git ls-files --ignored --exclude-standard --others

##输出配合 | grep 使用，验证目标文件是否被排除
```

# 版本控制

## 高频小幅迭代

### git commit --amend

**作用**

修改**最近一次提交**（`HEAD` 指向的提交）：

1. 追加新的暂存文件到上一次提交；
2. 可修改上一次的提交信息；
3. 不会产生新的提交节点，而是直接改写上一次提交的历史。

**进阶**

- 用 `-C HEAD` 参数复用上次提交信息，避免打开编辑器：

若提交已推送到 **公共分支**（如 `main`、`develop`），**绝对不要 amend + 强制推送！**会改写公共历史，导致他人代码冲突；

若提交仅推送到 **个人迭代分支**（如 `feature/xxx`），且无他人协作，**可安全强制推送（用 `--force-with-lease` 而非 `--force`）。**

```bash
git add.
git commit --amend -C HEAD
git push --force-with-lease
```

