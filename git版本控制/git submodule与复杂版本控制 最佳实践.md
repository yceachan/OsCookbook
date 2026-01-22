- `git submodule add `

  ```shell
  # 语法：git submodule add <子模块远程地址> <本地子目录路径>
  git submodule add https://github.com/yourname/os-knowledge.git os
  git submodule add https://github.com/yourname/mpu-knowledge.git mpu
  
  # 执行后会发生3件事：
  # 1. 创建子目录os/mpu，并克隆远程仓库内容到该目录；
  ######若目录下已存在git仓库，不会触发clone
  # 2. 主仓库根目录生成.gitmodules文件（记录子模块映射关系）；
  # 3. 主仓库根目录生成.git/modules/目录（存储子模块的.git数据，避免子目录下有.git冲突）
  ```

- 当直接在仓库添加子仓库时，子仓库会被主仓库忽略：

  ![image-20260107003340623](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/image-20260107003340623.png)

---

**默认情况下，Git Submodule 指向子模块仓库中的某个特定的提交，而不是某个分支。**

> [Git Submodule如何管理多个仓库Git Submodule如何管理多个仓库 在开发大型项目时，项目往往会依赖多 - 掘金](https://juejin.cn/post/7485276123253833762)

# submodule 基础操作

- `git submodule init`：从 `.gitmodules` 文件中读取子模块的配置，并在 `.git/config` 中注册。
- `git submodule update`：该命令会拉取子模块远程仓库的最新提交，并将主项目中的子模块指向该版本。**此时，子模块会切换到远程仓库的 `HEAD`，也就是最新的提交**。

>  ![image-20260107003846269](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/image-20260107003846269.png)

- status

  ```powershell
  PS C:\Eachan\Workspace> git submodule status
   74a9efdb32db509bf29e8859fd4b3dc147b34fe1 OsCookBook (heads/main)
  ```

  