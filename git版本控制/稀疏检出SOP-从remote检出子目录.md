# 从任意remote检出子目录

## 稀疏检出脚本`sparse_checkout.ps1`

>  [./sparse_checkout.ps1](./sparse_checkout.ps1)
>
> --> 在此仓库推向远程，raw url： `https://raw.githubusercontent.com/yceachan/OsCookbook/main/git%E7%89%88%E6%9C%AC%E6%8E%A7%E5%88%B6/sparse_checkout.ps1`
>
> -->本地使用 g-sparse profile function 直接调用remote 存储好的脚本，**并通过运行时编程实现复杂参数传递**

```powershell
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
```



## g-sparse profile封装：本地irm调用remote存储的检出脚本

- `irm` : Invoke-RestMethod

```powershell
function g-sparse { & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/yceachan/OsCookbook/main/git%E7%89%88%E6%9C%AC%E6%8E%A7%E5%88%B6/sparse_checkout.ps1"))) $args }

function obs_sync_config {

   g-sparse https://github.com/yceachan/OsCookbook/tree/main/.obsidian
}
```

# Addt

## 命令行检出所有文件类型的范例

```shell
# 2. 新建目录并进入
mkdir $localRepoDir 

cd $localRepoDir

# 3. 初始化Git仓库
git init

# 4. 开启完整模式稀疏检出（支持文件通配符）
git sparse-checkout init --no-cone

# 5. 配置需拉取的文件类型（md/h/cpp/c/txt）
git sparse-checkout add **/*.md **/*.h **/*.cpp **/*.c **/*.txt

# 6. 关联远程仓库
git remote add origin $remoteRepoUrl

# 7. 拉取指定分支代码（仅拉取匹配文件）
git pull origin $targetBranch
```

## curl irm wget

| **特性**         | **curl**                | **irm (PowerShell)**            | **wget**             |
| ---------------- | ----------------------- | ------------------------------- | -------------------- |
| **全称**         | Client URL              | Invoke-RestMethod               | World Wide Web Get   |
| **主要平台**     | Linux/Mac (Windows也有) | Windows                         | Linux/Mac            |
| **核心哲学**     | 传输数据 (Raw Data)     | 处理对象/API (Objects)          | 下载文件 (Files)     |
| **管道运行搭档** | `                       | sh`或`                          | bash`                |
| **典型用途**     | 几乎所有 Linux 安装脚本 | Windows 下安装 Scoop/Chocolatey | 下载大文件、镜像网站 |
| usage            | curl <url.sh> \| sh     | irm <url.ps1> \| iex            | wget \<files\>       |

### g-sparse 运行时元编程 实现剖析

::: 彩蛋

 <img src="https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/ea2b428484c124f9573bc4f669beb98b.png" alt="ea2b428484c124f9573bc4f669beb98b" style="zoom:50%;" />

:::

从**运行时元编程（Runtime Metaprogramming）**、**对象生命周期**以及**执行上下文（Execution Context）**的角度来解析这段代码。

这段代码实现了一种**无状态的远程动态执行（Stateless Remote Dynamic Execution）**模式。

```PowerShell
function g-sparse { & ([scriptblock]::Create((irm "URL..."))) $args }
```

---


这段单行函数实际上构建了一个包含 **I/O -> 编译 -> 调用 -> 参数绑定** 的完整执行管道。

- A. 传输层：Payload 获取 (`irm "..."`)
  - **操作**：`Invoke-RestMethod` 发起同步 HTTP GET 请求。
  - **数据类型**：返回 `System.String`。
  - **本质**：这是代码的**序列化（Serialized）**形式。此时代码仅作为文本数据存在，尚未被 PowerShell 引擎解析为抽象语法树（AST）。

- B. 编译层：运行时实例化 (`[scriptblock]::Create(...)`)
  - **操作**：调用 .NET 框架中 `System.Management.Automation.ScriptBlock` 类的静态工厂方法 `Create`。
  - **转换**：将非结构化的 `System.String` 编译为结构化的 `System.Management.Automation.ScriptBlock` 对象。
  - **技术含义**：
    - 这是**动态编译（Dynamic Compilation）**过程。PowerShell 引擎会在内存中解析文本，检查语法错误，并构建可执行对象。
    - 此过程完全在内存堆（Heap）中完成，**不涉及磁盘 I/O**（即 Fileless Execution，无文件执行），这在绕过基于文件的安全扫描（如某些静态杀软）时具有特征意义，但依然受 AMSI（Antimalware Scan Interface）监控。

- C. 执行层：调用操作符 (`&`)
  - **操作**：使用 Call Operator (`&`) 调用上一步生成的 `ScriptBlock` 实例。
  - **作用域（Scope）**：
    - `&` 会为该 ScriptBlock 创建一个**子作用域（Child Scope）**。
    - 这意味着脚本中定义的变量（除非显式声明为 `Global` 或 `Script` 作用域）在执行结束后会被垃圾回收（GC），不会污染当前的 `g-sparse` 函数作用域或全局会话。

- D. 参数传递：动态绑定 (`$args`)
  
  - **机制**：**参数透传（Argument Forwarding）**。
  - `$args` 是 PowerShell 的自动变量（类型为 `System.Object[]`），包含传递给父函数 `g-sparse` 的所有未绑定参数。
  - **行为**：这些参数被直接传递给动态生成的 `ScriptBlock` 的 `Param()` 块（如果远程脚本定义了的话）或作为其 `$args` 接收。

- 性能与安全分析 (Trade-off Analysis)

从工程角度看，这种模式有显著的权衡：

| **维度**                     | **分析**                                                     |
| ---------------------------- | ------------------------------------------------------------ |
| **延迟 (Latency)**           | **高**。每次调用通过 TCP/TLS 握手和 HTTP 传输。属于网络 I/O 密集型操作，阻塞主线程直到下载完成。 |
| **一致性 (Consistency)**     | **最终一致性**。强制同步远端 `master/main` 分支。优点是消除了本地版本漂移（Configuration Drift），缺点是受制于远端可用性。 |
| **安全性 (Security)**        | **缺乏完整性校验 (No Integrity Check)**。代码在“下载”与“执行”之间没有校验环节（如 SHA256 Hash 验证）。这不仅存在中间人攻击（MITM）风险，更面临供应链攻击风险（GitHub 仓库被 commit malicious code）。 |
| **可观测性 (Observability)** | **低**。由于代码不在本地磁盘，通过 `Get-Command` 或常规日志难以审计实际执行的逻辑。 |

