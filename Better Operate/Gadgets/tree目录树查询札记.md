
## 一、Bash 下的 tree 工具

bash（Linux/macOS 等类 Unix 系统的默认 Shell）有原生的 `tree` 命令行工具，功能成熟、参数丰富。

基础命令：直接在目标目录执行 `tree`，默认展示所有文件/目录的树形结构。

|        |                        |                        |
| ------ | ---------------------- | ---------------------- |
| 参数     | 作用                     | 示例                     |
| `-L N` | 限制展示的层级（N 为数字）         | `tree -L 2`（只展示 2 层目录） |
| `-d`   | 只显示目录，不显示文件            | `tree -d`              |
| `-f`   | 显示每个文件/目录的完整路径         | `tree -f`              |
| `-a`   | 显示隐藏文件（以 `.` 开头的文件/目录） | `tree -a`              |
| `-i`   | 不显示树形分支线，仅展示纯文本列表      | `tree -i`              |
| `-C`   | 彩色输出（默认开启，部分终端需手动指定）   | `tree -C`              |

## 二、PowerShell (pwsh) 下的 tree 工具


### 调用 Windows 原生的 [tree.com](http://tree.com)（最简单）

Windows 系统自带 `tree.com` 可执行文件，pwsh 中直接调用即可（兼容 Windows 仅，Linux/macOS 下 pwsh 无此命令）：

```PowerShell
# 基础用法：展示当前目录树形结构
tree.com

# 常用参数
tree.com /f  # 显示文件（默认只显示目录）
tree.com /a  # 用 ASCII 字符显示分支线（避免乱码）
tree.com /f /a  # 显示文件 + ASCII 分支线（推荐）
tree.com /f /a -L 2  # 限制层级（注：tree.com 仅支持 /f /a 核心参数，无层级限制，需手动筛选）
```


### 使用 wsl command

