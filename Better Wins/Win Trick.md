# pwsh7 profile proxy函数

```shell
# Set-Alias别名 sal
#等效 sal <name> <value>
Set-Alias -Name g -Value git

Set-Alias -Name grep -Value findstr

Set-Alias -Name touch -Value New-Item -Option AllScope

Set-Alias -Name which -Value where.exe

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
```



# 重启文件资源管理器

```
taskkill /F /IM explorer.exe
explorer.exe
```

# Sha256校验使用程序

```
#cmd
##sha.bat 将此脚本添加到path
certutil -hashfile %1 sha256
```

# Shell:sendto 右键实用菜单

导航栏输入`shell:sendto`

![image-20241026023436693](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202410260234763.png)

# 将win11右键菜单恢复回经典样式

| 网上教程比比皆是  [Windows11 恢复完整右键经典菜单-腾讯云开发者社区-腾讯云](https://cloud.tencent.com/developer/article/2187050)

```cmd
#cmd administors
reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f
taskkill /F /IM explorer.exe
explorer.exe
```

# 取消win 自动将最近文件固定到 快速访问

![image-20241026023852222](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202410260238293.png)

# sal别名与linux风格使用命令

## which

> win下有等效命令where.exe 但ps下必须带上后缀来使用，固为其配置sal （sel alias） 别名

```
#ps
code $PROFILE
---
#code
sal which where.exe
---
#ps
. $PROFILE
```

## grep

```
Set-Alias -Name grep -Value findstr
```

## touch

```
sal touch New-Item
```



# powershell7特性：&后台运行进程

如果在控制台启动typora，会启动它的日志输出占据终端，使用这个后台进程特性再合适不过。

注意仅在pwsh7中实现。

>  [从 Windows PowerShell 5.1 迁移到 PowerShell 7 - PowerShell | Microsoft Learn](https://learn.microsoft.com/zh-cn/powershell/scripting/whats-new/migrating-from-windows-powershell-51-to-powershell-7?view=powershell-7.4)

```powershell
typora ./README.md &
```

# mklink ln 软硬链接 OneDrive同步任意指定文件夹

仅在cmd下可用

![image-20241026024411239](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202410260244290.png)

最佳实践：在OneDrive目录下创建其他目录的链接，实现同步任意指定文件夹。

```
mklink /J ~/OneDrive ~/UserData
```



