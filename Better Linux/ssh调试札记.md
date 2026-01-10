# 终端可以访问github，git命令却无法访问仓库

当秘钥文件名不是默认的“id_xxx算法”时，需要额外配置ssh-agent

[OpenSSH for Windows 中基于密钥的身份验证 | Microsoft Learn](https://learn.microsoft.com/zh-cn/windows-server/administration/openssh/openssh_keymanagement)

这个服务是Open SSH for Windows 的子应用，git bash 不会调用这项服务。

假设创建了`id_chan`的秘钥，并成功在远程部署公钥，在wt上添加了秘钥`ssh-add`

那么，在wt中，ssh命令可以访问到远程主机`ssh -T git@github.com` 

但git命令是无法访问到远程仓库的`git push `

**解决方案：**

1.将秘钥更改为默认算法名字`id_ed25519`

2.在.ssh文件下创建`config`文件，配置远程主机登陆凭证

