# 并发竞争

1. 多线程并发访问， Linux是多任务（线程）的系统，所以[多线程](https://zhida.zhihu.com/search?content_id=212991783&content_type=Article&match_order=2&q=多线程&zhida_source=entity)访问是最基本的原因。
2. 抢占式并发访问，内核代码是可抢占的，因此，我们的驱动程序代码可能在任何时候丢失对处理器的独占
3. 中断程序并发访问，设备中断是异步事件，也会导致代码的并发执行。
4. SMP（多核）核间并发访问，现在ARM架构的多核SOC很常见，[多核CPU](https://zhida.zhihu.com/search?content_id=212991783&content_type=Article&match_order=1&q=多核CPU&zhida_source=entity)存在核间并发访问。正在运行的多个用户空间进程可能以一种令人惊讶的组合方式访问我们的代码，SMP系统甚至可在不同的处理器上同时执行我们的代码。

## 原子操作 atomic

```cpp
#include <Linux/atomic.h>
#include <asm/atomic.h>
```

![image-20250802111759249](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202508021117318.png)

* exam

```c
/// drv.c   ---> drv.ko
static atomic_t v = ATOMIC_INIT(1);
static int hello_drv_open (struct inode * node , struct file * file){
    if (! atomic_dec_and_test(&v) ) {  //原子 自减。并判断结果是否为零
        atomic_inc(&v);
        return -EBUSY;
    }
}
static int hello_drv_release(struct inode * node , struct file * file){
    atomic_inc(&v);
    return 0;
}

/// app.c   --->out :  ./a  ./b
int main () {
    fd = open("/dev/hello_drv", O_RDWR);
    print("hello!")
    sleep(5);
	close(fd);
}

///bash
insmod drv.ko
./a &
@hello!
./b
@cant not open file
./b  # wait for 5s
@hello!
```

## 自旋锁 spinlock

* 基本定义

自旋锁是一种**忙等待锁**。它的核心特点是**：**当一个线程**尝试进入一段被自选锁保护的临界区时**时，该线程会在一个**循环中不断检查锁的状态（即“自旋”）**，直到锁被释放。自旋锁**适用于临界区代码执行时间很短**的场景，**避免了线程上下文切换的开销。**

* 加锁流程

1. 检查锁状态（0=未锁定，1=锁定）
2. 若未锁定，尝试原子交换（0→1）
3. 若交换成功，获得锁
4. 若失败，循环执行步骤1-3

* 解锁流程

1. 原子写0到锁变量
2. 释放内存屏障保证可见性

`void spin_lock_irqsave(spinlock_t *lock, unsigned long flags);`

`spin_lock_irqsave()` 是 Linux 内核中**最安全、最完整的自旋锁获取函数**，它同时实现了三个关键功能：

1. **🔒 获取自旋锁**
   - 如果锁已被占用，当前 CPU 将自旋等待
   - 保证临界区的独占访问
2. **⚡ 禁用本地 CPU 中断**
   - 在获取锁的同时**禁用当前 CPU 的所有硬件中断**
   - 防止中断处理程序抢占当前执行流
3. **🛡️ 保存中断状态**
   - 将中断禁用前的状态保存到 `flags` 变量
   - 解锁时可精确恢复原始中断状态

* api

```c
DEFINE_SPINLOCK(spinlock);
#define DEFINE_SPINLOCK(x) spinlock_t x = __SPIN_LOCK_UNLOCKED(x)
```

![image-20250802141618423](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202508021416502.png)

### 死锁

死锁的模型是，第一个`spin_lock`的临界区休眠、阻塞，第二个spin_lock在此时尝试获取锁。此时在单核系统下，第一个spin_lock失去cpu使用权，无法运行到unlock函数，而第二个spin_lock片段在获取锁函数自选阻塞。此cpu核心就发生了死锁，无法解开。

## 信号量 semaphore

主要头文件：`<linux/semaphore.h>`

信号量本质是一个全局变量。当线程访问资源时，信号量自减，访问完后，信号量自增.

若信号量已为零后，新的进程尝试访问semaphore，将休眠等待至到信号量被释放出一个正值，才被唤醒并继续进行临界区，。

![image-20250802135420809](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202508021354883.png)

* down

`0`：成功；`-ETIME`：超时 ：成功； `-ETIME`：超时

> 睡眠等待 == 阻塞态
>
> 忙等待    ==  while轮询

![image-20250802135430609](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202508021354674.png)

* up

![image-20250802140700324](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202508021407381.png)

## 附 线程状态

* freeRTos

> 挂起==等待用户手动唤醒
>
> 阻塞==等待信号唤醒

![image-20250802140029800](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202508021400887.png)

* 📊 Linux 进程状态总览

| 状态             | 内核宏                 | 描述                   | `/proc` 表示 | `ps` 命令显示 |
| :--------------- | :--------------------- | :--------------------- | :----------- | :------------ |
| **运行/可运行**  | `TASK_RUNNING`         | 正在运行或就绪等待CPU  | `R`          | `R`           |
| **可中断睡眠**   | `TASK_INTERRUPTIBLE`   | 等待资源，可被信号唤醒 | `S`          | `S`           |
| **不可中断睡眠** | `TASK_UNINTERRUPTIBLE` | 等待硬件资源，不可中断 | `D`          | `D`           |
| **停止状态**     | `__TASK_STOPPED`       | 被信号暂停执行         | `T`          | `T`           |
| **跟踪状态**     | `__TASK_TRACED`        | 被调试器跟踪           | `t`          | `t`           |
| **僵尸状态**     | `EXIT_ZOMBIE`          | 进程已终止但资源未回收 | `Z`          | `Z`           |
| **死亡状态**     | `EXIT_DEAD`            | 最终消亡状态（瞬时）   | -            | -             |

## 互斥锁mutex

值取0、1 的信号量，api更加简洁

```c
#define DEFINE_MUTEX(mutexname) \
	struct mutex mutexname = __MUTEX_INITIALIZER(mutexname)


///
DEFINE_MUTEX(mutex1);
struct mutex mutex1 = {.count = {(1)},
                       .wait_lock =
                           (spinlock_t){{.rlock = {.raw_lock = {{0}}}}},
                       .wait_list = {&(mutex1.wait_list), &(mutex1.wait_list)}
```

![image-20250802140833098](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/202508021408164.png)