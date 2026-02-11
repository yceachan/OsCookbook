### Git LFS (Large File Storage) 应用速查札记

LFS 是解决你之前 `.rar`、`.pdf`、`.o` 等大文件导致仓库膨胀的最佳方案。它将大文件替换为文本指针，文件实体存储在专门的 LFS 服务器上。

#### 1. 什么时候用 LFS？

- **文件类型**：二进制文件 (图片, 视频, DLL, SO, 压缩包, PDF)。
- **文件大小**：超过 50MB (GitHub 限制 100MB，但在 50MB 时就会警告)。
- **场景**：你需要版本控制这些文件，但不需要 Diff（比较差异）。

#### 2. 初始化与配置

在任何使用 LFS 的机器上（你和队友）都需要先安装：

Bash

```
# 1. 安装 LFS 钩子 (只需执行一次)
git lfs install

# 2. 追踪特定文件 (生成 .gitattributes)
git lfs track "*.rar"
git lfs track "docs/*.pdf"
git lfs track "bin/**"

# 3. 提交配置文件 (非常重要！)
git add .gitattributes
git commit -m "chore: configure git lfs"
```

#### 3. 日常使用 (透明化)

配置好后，你就像平时一样用 git：

Bash

```
# 像普通文件一样添加
git add my_big_file.rar
git commit -m "add rar"
git push origin main
```

*当你 Push 时，你会看到上传进度条，那是 LFS 在单独上传大文件。*

#### 4. 迁移旧文件 (Migration)

**这是你现在最需要的。** 如果你有一些大文件已经在历史记录里了（仓库很大），或者你之前不想用 `git-filter-repo` 删掉它们，而是想把它们**转为 LFS 管理**：

Bash

```
# 自动查找大文件并转为 LFS 管理（重写历史）
git lfs migrate import --include="*.rar,*.zip" --everything

# 强制推送到远程 (覆盖旧历史)
git push --force-with-lease
```

*这个命令的效果类似 `filter-repo`，但它不是删除文件，而是把历史记录里的大文件实体替换成了 LFS 指针，保留了文件存在。*

#### 5. 常用命令速查

| **命令**           | **作用**                                                     |
| ------------------ | ------------------------------------------------------------ |
| `git lfs ls-files` | 查看当前哪些文件被 LFS 管理了                                |
| `git lfs track`    | 查看当前的追踪规则                                           |
| `git lfs pull`     | 手动下载当前分支的大文件（用于网速慢或 clone 时跳过下载的情况） |
| `git lfs prune`    | 清理本地旧版本的 LFS 缓存（释放本地硬盘空间）                |
| `git lfs status`   | 检查当前暂存区文件的 LFS 状态                                |

#### 6. 嵌入式开发者的 .gitattributes 模板

建议在你的嵌入式项目中添加以下 LFS 规则：

Plaintext

```
# 文档
*.pdf filter=lfs diff=lfs merge=lfs -text
*.docx filter=lfs diff=lfs merge=lfs -text

# 压缩包
*.rar filter=lfs diff=lfs merge=lfs -text
*.zip filter=lfs diff=lfs merge=lfs -text

# 芯片/烧录相关
*.bin filter=lfs diff=lfs merge=lfs -text
*.hex filter=lfs diff=lfs merge=lfs -text
*.elf filter=lfs diff=lfs merge=lfs -text
```