## 进阶操作：仅在主仓库删除 Submodule 索引，但保留工作区文件

有时我们希望取消子模块的关联，将其代码变成主仓库的普通文件夹（或仅仅是不再被 Git 追踪的普通文件），同时**不丢失本地已经下载的代码文件**。这就需要仅删除索引并清理配置文件。

以下是完整的操作流程：

### 第 1 步：从 Git 索引中移除子模块

使用 `--cached` 参数，这会让 Git 停止追踪该子模块，并从索引中移除关联，但**不会触碰工作区的文件**。

```bash
# 注意：路径末尾千万不要加斜杠 /
git rm --cached <path-to-submodule>
```

### 第 2 步：清理 `.gitmodules` 配置文件

打开项目根目录下的 `.gitmodules` 文件，找到并删除对应子模块的配置段落：

```ini
# 删除类似下面的内容
[submodule "path/to/submodule"]
    path = path/to/submodule
    url = https://github.com/user/repo.git
```

然后将修改提交到暂存区：

```bash
git add .gitmodules
```

### 第 3 步：清理 `.git/config` (主仓库本地配置)

打开主仓库的 `.git/config` 文件，手动删除对应的 `[submodule]` 记录。 或者使用命令行直接删除：

```bash
git config --remove-section submodule.<path-to-submodule>
```

*(注意：如果提示找不到该 section，说明之前可能没有 init，可以忽略)*

### 第 4 步：清理子模块内部的 `.git` 指针文件

此时 `<path-to-submodule>` 目录下依然保留着原有的代码文件，但包含一个 `.git` 文件（在较新版本的 Git 中，这是一个指向主仓库 `.git/modules/...` 的文本文件）。 为了让它彻底变成一个普通的文件夹，需要删除这个 `.git` 文件：

```bash
# Windows (PowerShell/CMD)
del <path-to-submodule>\.git
# Linux/Mac
rm <path-to-submodule>/.git
```

### 第 5 步：清理主仓库的底层缓存 (可选，强迫症清理)

子模块的实际 Git 数据（历史记录、对象等）存放在主仓库的 `.git/modules/<path-to-submodule>` 下。如果不打算再恢复这个子模块，可以将其底层数据删除以释放空间：

```bash
# Windows
rmdir /s /q .git\modules\<path-to-submodule>
# Linux/Mac
rm -rf .git/modules/<path-to-submodule>
```

### 第 6 步：提交 Git 历史记录

到这一步，子模块的索引和配置已经彻底被抹除。将这些“删除”操作提交到主仓库的历史记录中：

```bash
git commit -m "chore: remove submodule index and config for <path-to-submodule>, keeping workspace files"
```

### 附加步骤：将原代码作为普通文件重新加入主仓库 (如果需要)

如果你希望把保留下来的这些代码文件直接作为主仓库的一部分进行版本控制（从 submodule 转化为普通目录）：

```bash
git add <path-to-submodule>
git commit -m "chore: add <path-to-submodule> files as regular tracked files"
```