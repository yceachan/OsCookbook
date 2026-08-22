<#
.SYNOPSIS
通用Git目录稀疏检出工具 (CLI风格)

.DESCRIPTION
支持从任意远程Git仓库的特定分支，拉取指定子目录到本地。
采用Unix-style参数风格 (--url, --source)，支持 --help 查看帮助。

.EXAMPLE
.\sparse_checkout.ps1 --url "https://github.com/yceachan/OsCookbook.git" --source ".obsidian"

.EXAMPLE
.\sparse_checkout.ps1 -u "..." -b "dev" -s "src/utils" -t "MyUtils"
#>

# ---------------------------------------------------------
# 1. 自定义参数解析 (智能识别 + --param 风格)
# ---------------------------------------------------------
$Url = $null
$Source = $null
$Branch = "main"
$Target = $null
$ShowHelp = $false

function Show-Help {
    Write-Host @"
=== 通用Git稀疏检出工具 ===
用法:
  1. 智能识别 (推荐):
     .\sparse_checkout.ps1 [GitHub链接]
     链接格式: https://github.com/user/repo/tree/branch/path/to/dir

  2. 手动指定:
     .\sparse_checkout.ps1 --url <Git地址> --source <目录路径> [选项]

必选参数 (智能模式下自动识别):
  --url, -u       远程Git仓库地址
  --source, -s    子目录路径

可选参数:
  --branch, -b    远程分支名称
  --target, -t    本地保存路径 (默认: 当前目录下的同名文件夹)
  --help, -h      显示帮助

示例:
  .\sparse_checkout.ps1 https://github.com/yceachan/skills/tree/main/skills/xlsx
"@
}

# 1.1 参数预处理：扁平化处理 (修复 Invoke-Command/Alias 传递数组的问题)
$flatArgs = @()
if ($args.Count -eq 1 -and $args[0] -is [System.Array]) {
    $flatArgs = $args[0]
} else {
    $flatArgs = $args
}

# 1.2 参数解析循环
for ($i = 0; $i -lt $flatArgs.Count; $i++) {
    $arg = $flatArgs[$i]
    
    # 跳过空参数
    if ([string]::IsNullOrWhiteSpace($arg)) { continue }

    if ($arg.StartsWith("-")) {
        # 处理带前缀的参数
        $key = $arg.ToLower()
        switch ($key) {
            { $_ -in "--help", "-h", "-?" } { Show-Help; return }
            { $_ -in "--url", "-u" }        { if ($i + 1 -lt $flatArgs.Count) { $Url = $flatArgs[++$i] }; break }
            { $_ -in "--source", "--src", "-s" } { if ($i + 1 -lt $flatArgs.Count) { $Source = $flatArgs[++$i] }; break }
            { $_ -in "--branch", "-b" }     { if ($i + 1 -lt $flatArgs.Count) { $Branch = $flatArgs[++$i] }; break }
            { $_ -in "--target", "--dest", "-t" } { if ($i + 1 -lt $flatArgs.Count) { $Target = $flatArgs[++$i] }; break }
            Default { Write-Warning "忽略未知参数: $arg" }
        }
    } else {
        # 处理位置参数 (假设第一个非Flag参数是URL)
        if ($null -eq $Url) {
            $Url = $arg
        }
    }
}

# ---------------------------------------------------------
# 2. 智能URL解析 (GitHub Deep Link)
# ---------------------------------------------------------
# 尝试匹配: https://github.com/User/Repo/tree/Branch/Path/To/Dir
if (-not [string]::IsNullOrWhiteSpace($Url) -and $Url -match '^https?://github\.com/([^/]+)/([^/]+)/tree/([^/]+)/(.*)$') {
    $user = $matches[1]
    $repo = $matches[2]
    $detectedBranch = $matches[3]
    $detectedPath = $matches[4]

    Write-Host "🔍 识别到 GitHub 深度链接:"
    
    # 重新组装 Git Clone URL
    $newUrl = "https://github.com/$user/$repo.git"
    Write-Host "   -> 仓库: $newUrl"
    $Url = $newUrl

    # 仅当未显式指定时覆盖
    if ($Branch -eq "main" -or [string]::IsNullOrWhiteSpace($Branch)) { 
        $Branch = $detectedBranch 
        Write-Host "   -> 分支: $Branch"
    }
    
    if ([string]::IsNullOrWhiteSpace($Source)) { 
        $Source = $detectedPath 
        Write-Host "   -> 目录: $Source"
    }
}

# ---------------------------------------------------------
# 3. 校验必填参数
# ---------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($Url) -or [string]::IsNullOrWhiteSpace($Source)) {
    Write-Error "错误: 缺少必填参数 (Url 或 Source)。"
    Write-Error "提示: 请提供完整的 GitHub tree 链接，或使用 -u 和 -s 参数。"
    Show-Help
    return
}

# ---------------------------------------------------------
# 3. 主逻辑
# ---------------------------------------------------------

# 临时放开权限（仅当前进程）
if (-not (Get-ExecutionPolicy -Scope Process | Select-String -Pattern "Bypass|Unrestricted")) {
    Set-ExecutionPolicy Bypass -Scope Process -Force | Out-Null
}

$ErrorActionPreference = "Stop"

try {
    Write-Host "`n=== 开始执行稀疏检出 ==="

    # 路径处理
    if ([string]::IsNullOrWhiteSpace($Target)) {
        $folderName = Split-Path $Source -Leaf
        if ([string]::IsNullOrWhiteSpace($folderName)) { $folderName = $Source }
        $Target = Join-Path $PWD $folderName
    } else {
        $Target = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Target)
    }

    Write-Host "远程仓库: $Url ($Branch)"
    Write-Host "目标资源: $Source"
    Write-Host "本地路径: $Target"

    # 创建临时环境
    $TempWorkDir = Join-Path ([System.IO.Path]::GetTempPath()) ("git-sparse-" + [System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $TempWorkDir -Force | Out-Null
    Write-Host "`n[1/4] 创建临时工作区..."

    $OriginalLocation = Get-Location
    Set-Location $TempWorkDir

    # Git初始化
    Write-Host "[2/4] 初始化临时仓库..."
    git init -q
    git remote add origin $Url
    git config core.sparseCheckout true
    
    $FormattedSourcePath = $Source -replace "\\", "/"
    Set-Content -Path ".git/info/sparse-checkout" -Value $FormattedSourcePath -Encoding UTF8

    # 拉取
    Write-Host "[3/4] 拉取数据 (Depth=1)..."
    try {
        $gitOutput = git pull origin $Branch --depth=1 2>&1
        if ($LASTEXITCODE -ne 0) { throw $gitOutput }
    } catch {
        Write-Error "Git拉取失败，请检查URL或网络。"
        throw $_
    }

    if (-not (Test-Path $FormattedSourcePath)) {
        throw "远程仓库中未找到目录: $FormattedSourcePath"
    }

    # 部署
    Write-Host "[4/4] 部署到本地..."
    Set-Location $OriginalLocation
    if (-not (Test-Path $Target)) { New-Item -ItemType Directory -Path $Target -Force | Out-Null }
    
    $AbsSourcePath = Join-Path $TempWorkDir $FormattedSourcePath
    Copy-Item -Path "$AbsSourcePath\*" -Destination $Target -Recurse -Force

    Write-Host "`n✅ 成功！资源已同步至: $Target"

} catch {
    Write-Host "`n❌ 失败: $_"
    return
} finally {
    Set-Location $OriginalLocation
    if (Test-Path $TempWorkDir) { Remove-Item -Path $TempWorkDir -Recurse -Force -ErrorAction SilentlyContinue }
}