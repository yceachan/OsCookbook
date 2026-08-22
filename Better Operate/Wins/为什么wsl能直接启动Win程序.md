好问题。WSL 能直接运行 Windows 的 `.exe`,并不是"模拟执行",而是**Linux 侧的 exec 被拦截后,委托宿主机 Windows 去创建一个真正的 Windows 进程**。具体机制分两层:

## 1. binfmt_misc:让 Linux 内核"认识"PE 文件

Linux 内核本身只认识 ELF 格式,直接执行一个 Windows PE 文件会报 `Exec format error`。WSL 启动时,会向内核的 **binfmt_misc** 机制注册 Windows PE 格式(以 `MZ` 魔数开头),并把这个格式的"解释器"指定为 WSL 的 init 进程 `/init`。

也就是说:

```text
exec(/mnt/c/.../app.exe)
        │
        ▼
Linux 内核识别出 PE 头 → 不报错,改调 /init 接手
```

这一步是标准 Linux 能力(binfmt_misc 本来也是为 QEMU 跨架构执行、Java class 文件等设计的),WSL 只是借用它挂了一个处理 PE 的 handler。

## 2. `/init` 把进程创建请求发给 Windows

`/init` 判断目标确实是 Windows 程序后,会请求 Windows 侧创建进程,两条路线取决于 WSL 版本:

|          | 进程创建路径                                                 |
| -------- | ------------------------------------------------------------ |
| **WSL1** | Linux 进程本身就是跑在 NT 内核上的 *pico process*(通过 `lxcore`/`lxss` 的系统调用翻译层实现),`/init` 直接调 NT 的 `NtCreateUserProcess` 在 Windows 侧创建真实进程 |
| **WSL2** | Linux 跑在轻量 Hyper-V 虚拟机里的真实内核中,`/init` 通过 **Hyper-V socket**(hvsock/vmbus)把"创建进程"请求发回宿主机,由宿主机 Windows 创建进程 |

所以最后启动出来的是一个**货真价实的 Windows 进程**——完整的 Win32 API、DLL 加载、GUI 窗口都正常工作,它和你在 cmd/PowerShell 里启动的进程没有本质区别,只是父进程链的源头在 WSL 里。

## 3. 体验上的"无缝"来自配套翻译

创建进程的同时,WSL 还做了一系列转换,让两边看起来像同一个环境:

- **路径转换**:`/mnt/c/Users/...` ↔ `C:\Users\...`
- **环境变量共享**:通过 `WSLENV` 声明哪些变量要双向传递
- **参数和退出码映射**,stdin/stdout 重定向回 Linux 终端

反向同理:在 Windows 里运行 `wsl.exe`,也是通过这套 interop 通道在 Linux 侧发起执行。

一句话总结:**不是 WSL 会执行 exe,而是内核把 PE 文件的执行"外包"给了宿主机 Windows,再由 WSL 把两边环境粘起来**。WSL1 靠 syscall 翻译层实现,WSL2 靠虚拟机内的 `/init` 通过 Hyper-V socket 与宿主机通信实现。