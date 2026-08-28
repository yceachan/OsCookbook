---
title: Docker Daemon 代理环境配置
tags: [Docker, Proxy, Ubuntu, WSL2]
note_types : Essay
created: 2026-08-28
updated: 2026-08-28

---


# Docker Daemon 代理环境配置

> [!note]
> **适用环境：** Ubuntu 22.04 LTS、WSL2、systemd 管理的 rootful Docker Engine 29.7.2  
> **参考：** [Docker daemon proxy configuration](https://docs.docker.com/engine/daemon/proxy/)

Shell 中的代理只影响 `curl` 等前台程序。`docker pull` 由 systemd 启动的 `dockerd` 执行，必须为 Docker 服务单独配置代理。

## 配置

本机 HTTP 代理地址为 `http://127.0.0.1:7897`：

```bash
sudo install -d -m 0755 /etc/systemd/system/docker.service.d

printf '%s\n' \
  '[Service]' \
  'Environment="HTTP_PROXY=http://127.0.0.1:7897"' \
  'Environment="HTTPS_PROXY=http://127.0.0.1:7897"' \
  'Environment="NO_PROXY=localhost,127.0.0.1,::1"' |
  sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf >/dev/null
```

应用配置：

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl is-active docker
```

## 验证

```bash
systemctl show docker --property=Environment
docker info | grep -i proxy
docker pull nginx:alpine
```

`docker info` 应显示：

```text
HTTP Proxy: http://127.0.0.1:7897
HTTPS Proxy: http://127.0.0.1:7897
```

## 故障定位

```bash
# 代理链路正常时返回 HTTP 401，这是 Docker Registry 的预期响应
curl --proxy http://127.0.0.1:7897 -I https://registry-1.docker.io/v2/

journalctl -u docker --no-pager -n 100
```

常见错误：

```text
dial tcp ...:443: i/o timeout
```

说明 `dockerd` 正在直连或代理不可用。确认代理程序正在运行、端口仍为 `7897`，并重新加载 Docker 服务。

## 配置边界

| 配置 | 作用范围 |
|---|---|
| Shell `HTTP_PROXY` | `curl`、`wget` 等当前用户进程 |
| APT `Acquire::*::Proxy` | 软件包下载 |
| Docker daemon 代理 | 镜像 `pull`、`push` |
| Compose `environment` | 容器内应用访问外网 |

Docker daemon 代理不会自动注入容器。容器内应用需要代理时，应在 Compose 文件中单独设置环境变量。

## 移除

```bash
sudo rm -f /etc/systemd/system/docker.service.d/http-proxy.conf
sudo systemctl daemon-reload
sudo systemctl restart docker
```
