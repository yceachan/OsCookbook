# fork

`pid_t fork(void);` 

当PC指向 `pid_t fork(void)` 时， 进入系统调用，clone 一个当前 当前elf程序对应process 的内存空间完全镜像 （但采用写时复制优化） **然后父进程的子进程的PC 都会指向fork 的下一行!**

> [!note]
>
> 在用户态的程序，永远无法分辨自己是父进程还是子进程，elf对应的C Runtime 内存空间不维护这些信息。
>
> **但响应用户态fork 系统调用的内核态是可以感知并维护pid表的 （包括那些被进程创建的子进程，的parent指针）。**
>
> ---> 关于fork的返回值:
>
> - 若为父进程，返回子进程pid
> - 若为子进程，始终返回0
>
> ---> 在类unix系统上，一切进程都是被其他进程创建的,
>
> - 这个认知指向了一个进程调用树---> (引出根节点的`pid0 boot`，与`pid1 sbin/init` )
> - 引出孤儿进程

# Execv
 - `int execv(char *path , char*[] argv);`
 该系统调用会重置当前进程的所有SP与内存空间,并完全替换为所传入的程序的新内存空间

> [!Important]
>
>---> Linux下创建新进程标准流程：
>
>```c
>{
>  pid_t pid = fork();
> //after fork ,both their PC here：
>  if (pid == 0) {                            
>      execv (pathh , argv);                  // for child process
>     }
>     else if (pid < 0) return ERROR;            
>     else {
>         ...                                    // for parent process
>     }
>     // Aboove ，that so called `fork` (分叉). 
>    }
>    ```

 

- mermaid
   ![image-20260201002617798](https://ali-oss-yceachan.oss-cn-chengdu.aliyuncs.com/img-bed-typora/image-20260201002617798.png)

