tlrc: rust 实现的tldr客户端

```bash
cargo install tlrc --locked
echo $(tldr --config-path)
tldr --gen-config > "$(tldr --config-path)" #生成默认config文件，wins下默认没有
vim $(tldr --config-path)

#################
#在这个字段设置 languages = ["",""] 默认->回退 语言
[cache]
  ....
  languages = ["zh", "en"]
  
####

tldr --update #去github/release 下载pages
tldr --info

~/.config/tlrc ❯ tldr --info                                                  02:39:51
Cache: /home/pi/.cache/tlrc (last update: 18min, 49s ago)
Automatic update in 13d, 23h
Installed languages:
en       : 7118
zh       : 1492
total    : 8610 pages
```

