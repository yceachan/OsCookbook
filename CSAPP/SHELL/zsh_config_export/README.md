```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yceachan/OsCookbook/refs/heads/main/CSAPP/SHELL/zsh_config_export/install.sh)"
```

 命令解析：
   * curl -fsSL:
       * -f: 连接失败时不显示错误信息（静默失败）。
       * -s: 静默模式（不显示进度条）。
       * -S: 如果发生错误，显示错误信息。
       * -L: 跟随重定向（GitHub Raw 地址通常需要这个）。
   * bash -c "...": 将下载的内容作为 bash 脚本执行。