# CMD

```
W : set <var>=val  #<var>紧挨 =<val> 
R : set <var>
D : set <val>=     # =后为null
```



# PWSH

> [about_Environment_Variables - PowerShell | Microsoft Learn](https://learn.microsoft.com/zh-cn/powershell/module/microsoft.powershell.core/about/about_environment_variables?view=powershell-7.4)
>
> 与 Windows 不同，macOS 和 Linux 上的环境变量名称区分大小写。 例如，在非 Windows 平台上，`$Env:Path` 和 `$Env:PATH` 是不同的环境变量。

```
W : $env:<var> = ""   #val用”” 包装
R : $env:<var>
D : $env：<var> = null
```

使用 `Get-ChildItem` cmdlet 查看环境变量的完整列表：

```powershell
Get-ChildItem Env:
```

# Linux

| 命令                | 作用                                | 示例                                 |
| ------------------- | ----------------------------------- | ------------------------------------ |
| `env`               | 列出所有**全局环境变量**            | `env | grep PATH` 筛选 PATH 变量     |
| `printenv <变量名>` | 查看指定全局环境变量的值            | `printenv HOME` 输出 `/home/user`    |
| `echo $<变量名>`    | 查看指定变量（包括局部 shell 变量） | `echo $USER` 输出当前用户名          |
| `set`               | 列出所有**局部 shell 变量和函数**   | `set | grep TEST_VAR` 查找自定义变量 |
| `unset `            | 删除变量定义（当前shell）           |                                      |
| VAR_NAME=""         | 清空变量值但保留定义                |                                      |



- export

  ```
  export [-fnp][变量名称]=[变量设置值]
  ```

  **参数说明**：

  - -f 　代表[变量名称]中为函数名称。
  - -n 　删除指定的变量。变量实际上并未删除，只是不会输出到后续指令的执行环境中。
  - -p 　列出所有的shell赋予程序的环境变量。

