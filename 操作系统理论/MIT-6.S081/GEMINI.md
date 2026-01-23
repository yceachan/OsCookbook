# 项目上下文: MIT 6.S081 xv6 Labs (Ref-forkLab)

## 1. 项目概览
本项目包含 MIT 6.S081 "Operating System Engineering" 课程的参考解答与实现，基于 **xv6-riscv** 教学操作系统。
当前目录 `Ref-forkLab` 是一个包含多个实验（如 Copy-On-Write, File System, Traps）解决方案的参考目录。

*   **主要语言**: C (内核与用户态), RISC-V 汇编
*   **目标架构**: RISC-V (QEMU 模拟器)
*   **核心文档**: `reports/` 目录下包含详细的中文实验报告，解释了每个实验的实现思路。

## 2. 目录结构
*   **`kernel/`**: 操作系统内核源码。核心逻辑位于此处，包括：
    *   `proc.c`: 进程管理（调度、`fork`、`exit`）。
    *   `vm.c`: 虚拟内存管理（页表映射、缺页处理）。
    *   `kalloc.c`: 物理内存分配。
*   **`user/`**: 运行在 xv6 之上的用户态程序和测试代码 (如 `sysinfotest.c`, `call.c`)。
*   **`reports/`**: 各个 Lab 的中文实现报告 (例如 `COW.md`, `traps.md`, `fs.md`)，是理解代码修改逻辑的关键资源。
*   **`book-riscv-rev1.pdf`**: xv6 官方教科书。

## 3. 构建与运行
**注意**: 当前根目录下未发现 `Makefile`。
通常 xv6 项目使用以下命令（如果存在 Makefile）：
*   `make qemu`: 编译并启动 QEMU。
*   `make qemu-gdb`: 启动调试模式。

*由于缺少构建文件，此目录可能仅用于代码参考或阅读，而非直接在此目录下编译运行。*

## 4. 开发规范与核心概念
*   **代码风格**: 遵循 xv6 的紧凑 C 语言风格 (K&R)。
*   **关键 API (系统调用)**:
    *   `fork()`: 创建新进程（COW 实验的核心优化点）。
    *   `exec()`: 加载并运行新程序。
    *   `wait()`: 等待子进程结束。
    *   `sbrk()`: 调整进程堆大小。
*   **内存模型**: 区分内核地址空间与用户地址空间。COW (写时复制) 实验涉及对物理页引用计数的管理和页表权限（只读）的控制。
*   **并发控制**: 内核中使用自旋锁 (`spinlock`) 和睡眠锁 (`sleeplock`) 进行同步。
