# Ubuntu 双网卡上网优先级配置纪要

## 1. 核心问题
在具有两张网卡的 Ubuntu 系统中，设置其中一张网卡作为优先的互联网出口。

## 2. 解决方案
通过 `netplan` 修改网络配置，为每张网卡的默认路由设置不同的**跃点数（metric）**。**metric 值越低，优先级越高**。

对于两张都使用 DHCP 的网卡，通过 `dhcp4-overrides` 来指定 `route-metric`。
 - Netplan 使用的系统版本范围:

   Netplan 从 Ubuntu 17.10版本开始成为默认的网络配置工具，并延续至今。
### Netplan 关键配置 (`/etc/netplan/....yaml`)
#### dhcp配置
```yaml
network:
  ethernets:
    # 假设 ens33 是主网卡
    ens33:
      dhcp4: true
      dhcp4-overrides:
        route-metric: 100  # 设置较低的 metric 值，使其成为高优先级路由

    # 假设 ens38 是备用网卡
    ens38:
      dhcp4: true
      dhcp4-overrides:
        route-metric: 200  # 设置较高的 metric 值，使其成为低优先级路由

  version: 2
  # renderer: NetworkManager  <-- 指示由 NetworkManager 后端应用此配置
```
#### 静态ip配置
```yaml
This is the network config written by 'subiquity'
twork:
ethernets:
  # 优先上网的网卡 (Primary Internet NIC)
  ens33:
    dhcp4: no  # 如果是静态IP，设为no
    addresses:
      - 192.168.1.100/24
    routes:
      - to: default
        via: 192.168.1.1
        metric: 100 # <--- 设置一个较低的 metric
    nameservers:
      addresses: [8.8.8.8, 1.1.1.1]

  # 备用或内网网卡 (Secondary/Internal NIC)
  ens38:
    dhcp4: no
    addresses:
      - 10.0.2.15/24
    routes:
      - to: default
        via: 10.0.2.1
        metric: 200 # <--- 设置一个较高的 metric
    # 如果此卡仅用于内网，最佳实践是完全不设置网关
    # 这种情况下，可以删除上面的 "routes" 部分

version: 2
```
## 3. 调试步骤回顾

1.  **定位配置文件**: 在 `/etc/netplan/` 目录下找到 `.yaml` 配置文件。
2.  **修改配置**: 添加 `dhcp4-overrides` 和 `route-metric`。
3.  **修复权限问题**:
    *   **遇到的警告**: `Permissions for /etc/netplan/....yaml are too open.`
    *   **解决方法**: 收紧文件权限，仅允许 root 用户读写。
        ```bash
        sudo chmod 600 /etc/netplan/your-config-file.yaml
        ```
4.  **应用配置**:
    ```bash
    sudo netplan apply
    ```
5.  **验证结果**: 使用 `ip route` 命令检查默认路由 (`default via ...`) 的 `metric` 值是否已按预期设置。
