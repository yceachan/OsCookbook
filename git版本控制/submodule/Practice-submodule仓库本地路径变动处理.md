  submodule 信息存在 4 处，手动移动目录只动了文件系统，其余 3 处都要同步：

  位置: .gitmodules
  操作: 改 [submodule "..."] 名 + path =（必须仓库相对路径）
  ────────────────────────────────────────
  位置: .git/config
  操作: git config -f .git/config --remove-section submodule.<旧> 然后写入新 section（或重跑 git submodule init）
  ────────────────────────────────────────
  位置: Git index
  操作: git rm --cached <旧路径> + git add <新路径>
  ────────────────────────────────────────
  位置: .git/modules/<名>/
  操作: 若是 gitfile 形式还需把 modules 目录改名并修 .git 文件里的 gitdir:；你这个子模块的 .git 是完整目录，不需要动

  更省事的办法是一开始就用 git mv <旧> <新> — git 会自动同步 .gitmodules 和 index（但 .git/config 仍要 git submodule
  sync 跟上）。