# 基础命令

* `docker run`  创建并运行

`docker run <repo>[:tag]`：基于repo镜像，创建并运行一个容器

`-d`: 容器后台运行

`-p <port of Host>:<port of Contains>` : 容器映射端口

`--name` ：容器名称

`-e <KEY> = <VAL>`: 设置容器环境变量

* `docker pull/push`

* `docker images`

* `docker rmi` 删除镜像

* `docker build` 基于DOCKERFILE构建镜像

* `docker save` 压缩存储镜像

* `docker load` 加载镜像

* `docker stop`   运行→停止

* `docker start` :停止→运行

* `docker ps` process status

* `docker rm` 删除容器

* `docker logs` 查看日志

* `docker exec` 对容器执行命令

  `docker exec -it <contain> <shell>` 创造一个具备stdin的连接到容器内部的SHELL。

![image-20240813044221207](https://s2.loli.net/2024/08/13/4tloSgXeiZOAyKT.png)

## 数据卷挂载

**数据卷（volume）**是一个虚拟目录，是**容器内目录**与**宿主机目录**之间映射的桥梁。

容器内的本地目录，需要宿主作为存储介质，通过volume完成二者的双向映射。

容器与数据卷的挂载要在创建容器时配置，对于创建好的容器，是不能设置数据卷的。而且**创建容器的过程中，数据卷会自动创建**。

`docker run -v <volume>:<contains_path>` ![image-20240813052631187](https://s2.loli.net/2024/08/13/QwZutxiFspjSCVH.png)

数据卷总挂载在宿主机的`/var/lib/docker/volumes/<volume>/_data`中

![image-20240813053216773](https://s2.loli.net/2024/08/13/KIr5CABfREzNosm.png)

mounts：mnt，挂载的文件系统   volume ： 量词，卷 （文件系统的设备层级）

## 宿主目录挂载

`docker run -v <path of host> : <path of contains>`

# 镜像部署

## Dockerfile

描述镜像的组织构成（所谓应用运行所需最小框架）

FROM ： 基于基础镜像生成，如ubuntu环境，JRE环境的镜像环境。

ENV；RUN ; ENTRYPOINY  ：镜像构建命令

![image-20240813055524378](https://s2.loli.net/2024/08/13/RsJb3W2lUa4tEeD.png)

## Docker bulid

`docker build -t <repo>[:tag]`，在当前目录下，基于dockerfile构建镜像

## Docker commit

要知道，当我们运行一个容器的时候（如果不使用卷的话），我们做的任何文件修改都会被记录于容器存储层里。而 Docker 提供了一个 `docker commit` 命令，可以将容器的存储层保存下来成为镜像。换句话说，就是在原有镜像的基础上，再叠加上容器的存储层，并构成新的镜像。

```bash
docker commit [选项] <容器ID或容器名> [<仓库名>[:<标签>]]
```

慎用，使用 `docker commit` 命令虽然可以比较直观的帮助理解镜像分层存储的概念，但是实际环境中并不会这样使用。

`docker commit` 命令是黑箱操作，且会让镜像更加臃肿

## Docker export/import

导出容器快照为tar压缩文件，或import其生成镜像。

# 容器网络

## 容器互联

Docker镜像会给宿主机创建一个虚拟网卡。

`docker network` 可为容器群维护虚拟局域网络，易于实现容器间基于容器名的互相访问。

![image-20240813061557537](https://s2.loli.net/2024/08/13/kySRw23xs6X9bhg.png)

`docker run --network <net>` :在创建容器时指定其

## 外部访问

容器中可以运行一些网络应用，要让外部也可以访问这些应用，这是通过访问主机的端口映射。当使用 `-P` 标记时，Docker 会映射一个端口到内部容器开放的网络端口。

# 镜像仓库

一个容易混淆的概念是注册服务器（`Registry`）。实际上注册服务器是管理仓库的具体服务器，每个服务器上可以有多个仓库，而每个仓库下面有多个镜像。从这方面来说，仓库可以被认为是一个具体的项目或目录。例如对于仓库地址 `docker.io/ubuntu` 来说，`docker.io` 是注册服务器地址，`ubuntu` 是仓库名。

大部分时候，并不需要严格区分这两者的概念。

## Docker Hub

可以通过执行 `docker login` 命令交互式的输入用户名及密码来完成在命令行界面登录 Docker Hub。

你可以通过 `docker logout` 退出登录。

你可以通过 `docker search` 命令来查找官方仓库中的镜像，并利用 `docker pull` 命令来将它下载到本地。

用户也可以在登录后通过 `docker push` 命令来将自己的镜像推送到 Docker Hub。

```bash
docker push username/<local repo>[:tag]
```

## 私有仓库

[`docker-registry`](https://docs.docker.com/registry/) 是官方提供的工具，可以用于构建私有的镜像仓库。

你可以使用官方 `registry` 镜像来运行。

```bash
$ docker run -d -p 5000:5000 --restart=always --name registry registry
```

这将使用官方的 `registry` 镜像来启动私有仓库。默认情况下，仓库会被创建在容器的 `/var/lib/registry` 目录下。你可以通过 `-v` 参数来将镜像文件存放在本地的指定路径。例如下面的例子将上传的镜像放到本地的 `/opt/data/registry` 目录。

```bash
$ docker run -d \
    -p 5000:5000 \
    -v /opt/data/registry:/var/lib/registry \
    registry
```

# 容器使用

1.启动容器时启动其内应用，作为软件沙盒

`docker run --rm  -v /home/work  -w /home/work zhanglianpin/stm32_compile_env make`

--rm 运行一个容器，并在命令结束后删除容器

-v      为容器的文件系统挂载数据卷