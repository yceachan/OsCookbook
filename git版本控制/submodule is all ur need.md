# Git Submodule Is All Your Need

以下是 `git submodule` 各项指令的核心功能总结。为了方便理解，将它们按**使用场景**进行了分类：

## 1. 基础添加与移除 (Lifecycle)
*   **`add`**：**添加子模块**。将一个外部 Git 仓库链接到当前项目中，并在 `.gitmodules` 文件中记录相关信息。
    *   *示例：`git submodule add <repo-url> <path>`*
    *   这会将主工作区下，submodule 的根文件夹，视为（指向当前commit的）指针文件而非路径
        - [!tip]: 使用`git add <submodule_base>` 即可同步submodule的本地commit更新。
*   **`init`**：**初始化子模块**。将 `.gitmodules` 文件中的子模块配置（如 URL 等）注册到本地的 `.git/config` 中，为拉取代码做准备。
*   **`deinit`**：**注销/卸载子模块**。清空子模块的工作区，并从 `.git/config` 中移除相关配置。相当于 `init` 的反向操作。

## 2. 更新与同步 (Update & Sync)
*   **`update`**：**更新子模块代码**。根据主仓库中记录的 commit 状态，拉取并检出（checkout）子模块对应的代码版本。通常克隆包含子模块的仓库后，会使用 `git submodule update --init --recursive`。
*   **`sync`**：**同步远程地址**。如果你在 `.gitmodules` 中手动修改了子模块的源 URL，运行此命令可以将新 URL 同步到主仓库的 `.git/config` 以及子模块本身的配置文件中。

## 3. 状态与信息查看 (Status & Info)
*   **`status`**：**查看子模块状态**。显示各个子模块当前的 commit ID、所在路径以及标签信息。如果前面带有 `+`、`-` 或 `U`，分别代表有新提交、未初始化或有冲突。
*   **`summary`**：**查看提交差异摘要**。比较当前主仓库记录的子模块 commit 和子模块实际 HEAD 的差异，列出新旧版本之间的 commit 简报。

## 4. 属性修改 (Configuration)
*   **`set-branch`**：**设置跟踪分支**。修改 `.gitmodules` 文件，指定该子模块默认应该跟踪哪个分支（如 `main` 或 `dev`）。
*   **`set-url`**：**设置新的源地址**。修改 `.gitmodules` 文件中该子模块的远程仓库 URL。

## 5. 批量操作与高级维护 (Advanced)
*   **`foreach`**：**批量执行命令**。遍历所有子模块，并在每个子模块所在的目录下执行你指定的 Shell 命令。
    *   *示例：`git submodule foreach 'git status'`*
*   **`absorbgitdirs`**：**吸收 Git 目录**。将原本存在于子模块目录下的 `.git` 文件夹移动到主仓库的 `.git/modules/` 目录下，并在子模块原位置留下一个 `.git` 文件指针。这能防止在主仓库切换分支或执行清理时意外丢失子模块的本地历史记录。现代 Git 默认在添加子模块时就会这么做。

---

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
打开主仓库的 `.git/config` 文件，手动删除对应的 `[submodule]` 记录。
或者使用命令行直接删除：
```bash
git config --remove-section submodule.<path-to-submodule>
```
*(注意：如果提示找不到该 section，说明之前可能没有 init，可以忽略)*

### 第 4 步：清理子模块内部的 `.git` 指针文件
此时 `<path-to-submodule>` 目录下依然保留着原有的代码文件，但包含一个 `.git` 文件（在较新版本的 Git 中，这是一个指向主仓库 `.git/modules/...` 的文本文件）。
为了让它彻底变成一个普通的文件夹，需要删除这个 `.git` 文件：
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