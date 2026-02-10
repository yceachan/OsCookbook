- `~/.ssh/config`

  ```shell
  #normal template : Host * specify Alive cfg , then others onglu nedd hostname & user
  Host *
      TCPKeepAlive yes
      ServerAliveInterval 60
      ServerAliveCountMax 5
  Host vbu
      HostName 192.168.0.101
      User pi
      Port 22
  ```

- `chmod 600 ~/.ssh/config`
- `chmod 700 ~/.ssh`

目录的权限必须是仅用户rwx700 ，而config/authorized_keys 则是仅用户可读写600

