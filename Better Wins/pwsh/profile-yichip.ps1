sal g git
sal which where.exe
sal grep findstr
sal touch new-Item
Import-WslCommand "file","head","tail"

function tree {
    param(
        [Parameter(Position=0)]
        [string]$Path = ".",  # 路径缺省为当前目录
        [Parameter(ValueFromRemainingArguments)]
        $RawArgs  # 接收所有原始参数（含-l/-d等）
    )
    # 核心：替换小写-l为大写-L，兼容-l 3 / -l3 两种写法
    $Args = $RawArgs | ForEach-Object {
        if ($_ -match '^-l(\d*)$') { "-L$($matches[1])" }  # 匹配-l/-l3 → 转-L/-L3
        else { $_ }  # 其他参数原样保留
    }
    # 调用WSL的tree，自动转换Windows路径为Linux格式
    wsl /snap/bin/tree $Path $Args
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
