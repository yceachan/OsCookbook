[PowerShell WSL交互：无缝整合Linux命令到Windows环境-CSDN博客](https://blog.csdn.net/gitblog_01300/article/details/143049522)

- 安装模块
```pwsh
Install-Module WslInterop
```

- 配置profile
```pfofile
Import-WslCommand "file","grep","touch"
```

