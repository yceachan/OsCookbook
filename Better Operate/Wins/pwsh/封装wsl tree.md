[[../../CSAPP/SHELL/tree目录树查询札记]]
```sh
function tree {

    param(

        [Parameter(Position=0)]

        [string]$Path = ".",  # 路径缺省为当前目录

        [Parameter(ValueFromRemainingArguments)]

        $RawArgs  # 接收所有原始参数（含-l/-d等）

    )

    # 核心：替换小写-l为大写-L，兼容-l 3 / -l3 两种写法

    $Args = $RawArgs | ForEach-Object {

        if ($_ -match '^-l(\d*)$') { "-L$($matches[1])" }  # 匹配-l/-l3 → 转-L/-L3

        else { $_ }  # 其他参数原样保留

    }

    # 调用WSL的tree，自动转换Windows路径为Linux格式

    wsl /snap/bin/tree $Path $Args

}
```
