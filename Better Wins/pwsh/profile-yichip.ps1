sal g git
sal which where.exe
sal grep findstr
sal touch new-Item
Import-WslCommand "file","head","tail"


function g-sparse { & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/yceachan/OsCookbook/main/git%E7%89%88%E6%9C%AC%E6%8E%A7%E5%88%B6/sparse_checkout.ps1"))) $args }

function obs_sync_config {

   g-sparse https://github.com/yceachan/OsCookbook/tree/main/.obsidian
}

function fork_obs {
    <#
    .SYNOPSIS
        在当前目录下创建到 D:\Oscookbook\.obsidian 的目录联接。
    #>
    $target = "D:\Oscookbook\.obsidian"
    $link = Join-Path (Get-Location) ".obsidian"

    if (Test-Path $link) {
        Write-Error "错误：当前路径下已存在 .obsidian。"
        return
    }

    if (-not (Test-Path $target)) {
        Write-Error "错误：目标路径 $target 不存在。"
        return
    }

    # 执行创建命令，遵循 UTF-8 规范
  cmd /c mklink /j ".obsidian" "$target"
}


function update_gemini {
    npm install -g @google/gemini-cli@latest
}
function proxy {
    $env:http_proxy = "http://127.0.0.1:7897"
    $env:https_proxy = "http://127.0.0.1:7897"
    [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy("http://127.0.0.1:7897")
    Write-Host "Proxy enabled: http://127.0.0.1:7897" -ForegroundColor Green
}

function unproxy {
    $env:http_proxy = $null
    $env:https_proxy = $null
    [System.Net.WebRequest]::DefaultWebProxy = $null
    Write-Host "Proxy disabled" -ForegroundColor Yellow
}

function check-proxy {
    if ($env:http_proxy -or $env:https_proxy) {
        Write-Host "Current proxy settings:" -ForegroundColor Cyan
        Write-Host "HTTP Proxy: $env:http_proxy"
        Write-Host "HTTPS Proxy: $env:https_proxy"
    } else {
        Write-Host "No proxy is currently set." -ForegroundColor Cyan
    }
}
