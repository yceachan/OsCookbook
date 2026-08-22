

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


# powershell7特性：&后台运行进程

如果在控制台启动typora，会启动它的日志输出占据终端，使用这个后台进程特性再合适不过。

注意仅在pwsh7中实现。

>  [从 Windows PowerShell 5.1 迁移到 PowerShell 7 - PowerShell | Microsoft Learn](https://learn.microsoft.com/zh-cn/powershell/scripting/whats-new/migrating-from-windows-powershell-51-to-powershell-7?view=powershell-7.4)

```powershell
typora ./README.md &
```

# mklink ln 软硬链接 OneDrive同步任意指定文件夹

仅在authcmd下可用

![image-20241026024411239](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202410260244290.png)

最佳实践：在OneDrive目录下创建其他目录的链接，实现同步任意指定文件夹。

```
mklink /J ~/OneDrive ~/UserData
```



