# ************************ 第一步：配置参数 ************************
# 替换为你的SVN仓库PCB目录URL
$svnUrl = "https://47.102.118.39/svn/SoYeah_HW/PCB"
# 本地检出路径（匹配你的工作目录）
$localPath = "D:\Workspace\Yichip\SVN\PCB"

# ************************ 第二步：执行稀疏检出 ************************
# 1. 检出PCB根目录（深度：直接子节点，包含文件夹 → 一级空目录）
svn checkout --depth immediates --ignore-externals $svnUrl $localPath

# 2. 遍历PCB下所有一级子目录，设置深度为“直接子节点”（生成二级空目录）
Get-ChildItem -Path $localPath -Directory | ForEach-Object {
    # 对每个一级子目录执行更新，生成其下二级空目录
    svn update --set-depth immediates --ignore-externals $_.FullName
}

# ************************ 第三步：验证结果 ************************
# 显示检出后的目录树前20行，确认层级符合要求
tree $localPath /A | Select-Object -First 20