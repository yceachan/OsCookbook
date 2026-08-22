# Windows 路由精细配置指南

在多网卡环境（如同时连接 WiFi 和 USB 有线网卡）下，常常需要调整路由跃点数（Metric）或添加特定网段的路由来控制流量走向。本文档总结了在 Windows 下进行精细路由配置的核心思路与实操命令。

## 核心概念解析

1. **直连路由 (On-link)**
   如果网卡本身的 IP 在目标网段内（例如网卡 IP 为 `192.168.31.101`，要访问 `192.168.31.0/24`），这属于“直连网络”。
   - **绝对不要**为直连网络指定同网段的网关。
   - 强行指定网关（如把网关设为 `192.168.31.31`）会导致路由逻辑冲突，数据包无法直接发送给目标主机，从而导致 Ping 不通。
   - 正确的做法是网关保持为 `0.0.0.0` 或显示为 `On-link`。

2. **跃点数 (Metric) 的计算规则**
   在 `route print` 中看到的最终 Metric 是一个加法运算结果：
   **最终 Metric = 网卡接口跃点数 (Interface Metric) + 路由条目基础跃点数 (Route Metric)**
   *（注：Metric 值越小，优先级越高。）*
   *系统默认会为直连(On-link)路由分配固定的基础跃点数 256。*

3. **持久化 (Persistence)**
   - 使用 PowerShell 配置的接口属性默认写入注册表，永久生效，但不会显示在 `route print` 结尾的“Persistent Routes”列表中。
   - 只有通过 `route -p add` 明确添加的静态路由，才会显示在“Persistent Routes”中。

---

## 常见场景实操

### 场景一：修改整张网卡的优先级 (Interface Metric)
如果你希望系统在可能的情况下优先（或延后）使用某张网卡，可以直接修改该网卡的接口跃点数。此配置永久生效。

**1. 关闭自动跃点数并设置固定值：**
以管理员身份运行 PowerShell：
```powershell
# 使用网卡名称 (Alias)
Set-NetIPInterface -InterfaceAlias "localDevp" -AutomaticMetric Disabled -InterfaceMetric 60

# 或者使用接口索引 (Index，可通过 route print 查看)
Set-NetIPInterface -InterfaceIndex 15 -AutomaticMetric Disabled -InterfaceMetric 60
```

**2. 还原回自动分配：**
```powershell
Set-NetIPInterface -InterfaceAlias "localDevp" -AutomaticMetric Enabled
```

### 场景二：添加持久化直连路由
如果不希望修改网卡接口的全局 Metric，只想针对某个特定网段（如 `192.168.31.0/24`）指定跃点数，可使用静态路由。

以管理员身份运行命令提示符或 PowerShell：
```cmd
:: 语法: route -p add <目标网段> mask <子网掩码> <网关> metric <跃点数> if <接口索引号>
:: 对于直连网段，网关写 0.0.0.0。
route -p add 192.168.31.0 mask 255.255.255.0 0.0.0.0 metric 60 if 15
```
*执行后，该记录将永久出现在 `route print` 的 Persistent Routes 列表中。*

### 场景三：添加跨网段网关路由
如果你的 USB 网卡连接了一台设备（如 `192.168.31.31`），该设备作为路由器可以带你访问另一个网段（如 `10.0.0.0/8`）：
```powershell
New-NetRoute -DestinationPrefix "10.0.0.0/8" -InterfaceAlias "localDevp" -NextHop "192.168.31.31" -RouteMetric 60
```

---

## 故障排查 (Troubleshooting)

**症状**：配置路由后无法 Ping 通目标网段主机。
**原因**：极大概率是为“同网段（直连网段）”错误地指定了网关。在 `route print` 中会看到类似 `192.168.31.0  255.255.255.0  192.168.31.31` 的记录。
**解决**：删除该错误路由，让系统恢复默认的 `On-link` 状态。

```cmd
:: 删除错误的静态路由
route delete 192.168.31.0 mask 255.255.255.0 192.168.31.31

:: PowerShell 方式
Remove-NetRoute -DestinationPrefix "192.168.31.0/24" -NextHop "192.168.31.31" -Confirm:$false
```