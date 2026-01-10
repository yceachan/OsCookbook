这是ubuntu的一种设计思想，以sshd 服务器配置文件距离：

 1. **/etc/ssh/sshd_config**
   * 作用: 这是 OpenSSH 服务器的 **主配置文件。它包含了绝大多数的全局设置。**
   * 常见配置:
       * Port 22：监听的端口号。
       * PermitRootLogin prohibit-password：是否允许 root 用户登录。
       * PasswordAuthentication yes：是否允许使用密码登录。
       * PubkeyAuthentication yes：是否允许使用密钥对登录。
   * 总结: 这是您配置 SSH 服务器行为的核心文件。

  2. **/etc/ssh/sshd_config.d/**
   * 作用: **这是一个 配置片段目录。该目录下的 .conf 文件用于补充或覆盖**
     **sshd_config 中的设置。**
   * 目的:
       * 模块化: 您可以按**功能将配置拆分到不同文件中（例如，50-security.conf,**
         **60-logging.conf）。**
       * 易于管理: 当其他软件（如 fail2ban）需要修改 SSH
         配置时，它们可以安全地在此目录中添加一个文件，而无需直接修改
         sshd_config 主文件，从而避免了在软件升级时可能发生的冲突。
   * 总结: 用于存放零散、模块化或由其他软件包自动生成的服务器配置文件

  **服务器配置的优先级**
  配置的加载和生效遵循一个简单的规则：后面读取的配置会覆盖前面读取的相同配置

 1. 系统首先读取 /etc/ssh/sshd_config。
   2. 然后，系统按 字母顺序 读取 /etc/ssh/sshd_config.d/ 目录下的所有 .conf
      文件。
   3. 最终生效的规则是“后来者居上”。例如，如果在 sshd_config 中设置了 Port
      22，但在 sshd_config.d/99-custom.conf 文件中设置了 Port 2222，那么 SSH
      服务器最终会监听 2222 端口。

 **客户端配置的优先级**
  客户端的配置层级更多，规则也略有不同：最先匹配到的规则生效。

   从高到低，优先级顺序如下：

   1. 命令行选项: 最高优先级。例如 ssh -p 2222 user@host
      会无视任何配置文件中的端口设置。
   2. 用户个人配置文件: ~/.ssh/config。这是 最常用
      的用户自定义配置文件，仅对当前用户生效。它会覆盖系统级的设置。
   3. 系统级配置文件:
       * 首先读取 /etc/ssh/ssh_config。
       * 然后按 字母顺序 读取 /etc/ssh/ssh_config.d/ 目录下的 .conf 文件。

  关键区别:
  与服务器端“后来者居上”不同，客户端在解析配置文件时，对于一个特定的连接参数（
  如 Port），它会使用 它找到的第一个匹配的设置，然后停止寻找该参数。所以
  ~/.ssh/config 中的设置会优先于 /etc/ssh/ssh_config 中的设置。