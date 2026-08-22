# Git Submodule Is All Your Need

以下是 `git submodule` 各项指令的核心功能总结。为了方便理解，将它们按**使用场景**进行了分类：

## 1. 基础添加与移除 (Lifecycle)
*   **`add`**：**添加子模块**。将一个外部 Git 仓库链接到当前项目中，并在 `.gitmodules` 文件中记录相关信息。
    *   *示例：`git submodule add <repo-url> <path>`*
    *   这会将主工作区下，submodule 的根文件夹，视为（**指向当前commit(而非Branch**)的）指针文件而非路径
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

