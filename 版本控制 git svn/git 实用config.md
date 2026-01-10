# 配置utf8编码

```shell
#1.关闭转义 （必配，否则只显示ascii字符），配置后，错误编码会显示锟斤拷而非转义字符
git config --global core.quotepath false
# 2. 设置 Git 提交/日志的字符编码为 UTF-8
git config --global i18n.commitencoding utf-8
git config --global i18n.logoutputencoding utf-8

# 3. 配置 Windows 终端的编码为 UTF-8（避免终端显示乱码）
# （Git Bash 已默认支持，PowerShell 需额外设置）
# PowerShell 中执行：chcp 65001（临时生效，重启后需重新执行）
# 若需 PowerShell 永久生效，需修改注册表（可选，下文补充）

# 4. 验证配置是否生效
git config --global --list | grep -E "quotepath|encoding"
```

![image-20260106235849589](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/image-20260106235849589.png)

# 配置邮箱

```
git config --global user.name "衣陈"
git config --global user.email "yceachan@foxmail.com"
```

# 配置默认本地分支名

```
git config --global init.defaultBranch <name>
```

# .gitignore 验证忽略文件

```bash
# 语法：git ls-files --ignored --exclude-standard --others
git ls-files --ignored --exclude-standard --others

##输出配合 | grep 使用，验证目标文件是否被排除
```

# 快捷 amend commit

todo ： 回宿舍后在那里补充这部分的快速应用命令
