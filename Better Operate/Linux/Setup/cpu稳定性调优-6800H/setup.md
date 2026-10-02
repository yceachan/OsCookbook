# Fedora 44：Ryzen 7 6800H 降频、禁用 Boost 与睡眠

## 背景

- 设备：Lenovo ThinkBook 16p NX ARH（21EV）
- CPU：AMD Ryzen 7 6800H with Radeon Graphics
- GPU：AMD Radeon 680M + NVIDIA RTX 3050 Mobile
- 系统：Fedora Linux 44 KDE
- 排查时内核：`6.19.10-300.fc44.x86_64`
- BIOS：`KJCN35WW`（2024-09-29）
- 调整日期：2026-09-04

这颗 CPU 已出现疑似硬件老化/缩缸。在 Windows 下需要使用以下电源设置才能降低冷启动、低负载 BSOD 和睡眠后无法唤醒的概率：

- 最大处理器状态：99%（实际意图是禁用 Boost）
- 最小处理器状态：80%
- 永不睡眠

本页记录 Fedora 下的行为等效配置和排查轨迹。本次按使用者决定跳过内核更新。

## 排查轨迹

### 初始状态

Fedora 最初使用 TuneD 的 `balanced` 配置：

```text
amd-pstate mode: active
scaling driver: amd-pstate-epp
governor: powersave
EPP: balance_performance
Boost: 1
最低频率: 1095838 kHz
最高频率: 4787082 kHz
```

CPU 固件通过 CPPC 报告：

```text
nominal_freq=3201 MHz
lowest_freq=400 MHz
```

因此 Windows 的 80% 最小处理器状态按非 Boost 标称频率换算约为：

```text
3201 MHz * 80% = 2560.8 MHz
```

最终采用 `2561000–3201000 kHz` 的范围，并显式关闭 Boost。

### 睡死证据

一次异常关机前的最后内核记录为：

```text
systemd-logind: The system will suspend now!
systemd-sleep: Performing sleep operation 'suspend'...
kernel: PM: suspend entry (s2idle)
```

之后没有任何 resume 记录，系统直接进入下一次启动。机器只提供 `s2idle`，因此该次故障与睡眠电源管理直接相关。

### 低负载崩溃

另外两次运行中的崩溃没有经过 suspend，journal 日志直接中断，`last -x` 将会话标记为 `crash`。当时未发现以下记录：

- Kernel panic 的完整尾部
- MCE / Machine Check
- EDAC 内存错误
- 过热或 thermal throttling
- AMD GPU reset/timeout

这类现象符合硬锁死或突然复位，但旧日志不足以单独证明根因。为后续取证，最终启用了 kdump。

### DRM 警告不是本次 panic 证据

每次开机都会出现 `nouveau`、`amdgpu`、`simple-framebuffer` 交接期间的 DRM warning，例如：

```text
drm_mode_config_cleanup
drm_gem_shmem_release
connector Unknown-1 leaked
```

相同 warning 出现后系统仍可继续运行，因此它不是致命 panic。日志里的 `Registered ... with drm panic` 是 DRM 应急显示功能名称，也不表示系统已经 panic。

### TuneD 配置第一次没有持久生效

第一次创建 `6800h-stable` 后，现场检查发现：

```text
Current active profile: balanced
profile_mode=auto
Boost=1
```

随后手动切换到 `6800h-stable`，即时检查正常，但重启后又恢复为 `balanced`。日志证明：

1. `6800h-stable` 在启动时成功应用，Boost 被设为 `0`。
2. KDE 查询 Power Profiles D-Bus 接口。
3. `tuned-ppd` 即使被 `disable`，仍被 D-Bus 自动拉起。
4. `tuned-ppd` 把配置重新切换成 `balanced`，Boost 又变成 `1`。

因此仅执行 `systemctl disable --now tuned-ppd.service` 不够；必须 mask 该服务。

## 最终配置

### 1. 系统级禁止睡眠和休眠

文件：`/etc/systemd/sleep.conf.d/99-disable-sleep.conf`

```ini
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowSuspendThenHibernate=no
AllowHybridSleep=no
```

创建命令：

```bash
sudo install -d -m 0755 /etc/systemd/sleep.conf.d

sudo tee /etc/systemd/sleep.conf.d/99-disable-sleep.conf >/dev/null <<'EOF'
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowSuspendThenHibernate=no
AllowHybridSleep=no
EOF

sudo systemctl daemon-reload
```

### 2. 创建 6800H 稳定 TuneD 配置

文件：`/etc/tuned/profiles/6800h-stable/tuned.conf`

```ini
[main]
summary=Ryzen 6800H degraded CPU stability workaround
include=balanced

[cpu]
boost=0
energy_performance_preference=performance
force_latency=cstate.name:C1|1

[sysfs]
/sys/devices/system/cpu/cpufreq/policy*/scaling_max_freq=3201000
/sys/devices/system/cpu/cpufreq/policy*/scaling_min_freq=2561000
```

创建和激活命令：

```bash
sudo install -d -m 0755 /etc/tuned/profiles/6800h-stable

sudo tee /etc/tuned/profiles/6800h-stable/tuned.conf >/dev/null <<'EOF'
[main]
summary=Ryzen 6800H degraded CPU stability workaround
include=balanced

[cpu]
boost=0
energy_performance_preference=performance
force_latency=cstate.name:C1|1

[sysfs]
/sys/devices/system/cpu/cpufreq/policy*/scaling_max_freq=3201000
/sys/devices/system/cpu/cpufreq/policy*/scaling_min_freq=2561000
EOF

sudo tuned-adm profile 6800h-stable
```

TuneD 的 `min_perf_pct` 在本系统中是针对 Intel P-State 的选项，不能用它可靠控制 AMD P-State，所以这里直接设置 `scaling_min_freq` 和 `scaling_max_freq`。

### 3. 阻止 KDE 覆盖 TuneD 配置

普通的 `disable` 无法阻止 D-Bus 激活 `tuned-ppd`。最终执行：

```bash
sudo systemctl mask --now tuned-ppd.service
sudo tuned-adm profile 6800h-stable
```

代价是 KDE 的“节能/平衡/性能”电源模式切换接口不再工作；这是预期行为，应由固定的 `6800h-stable` 配置接管 CPU 策略。

### 4. 从内核启动早期限制 C-state

为了避免 TuneD 启动之前进入不稳定的深度空闲态，给所有已安装内核加入：

```bash
sudo grubby --update-kernel=ALL \
  --args="processor.max_cstate=1 idle=nomwait"
```

生效后：

```text
current_driver=acpi_idle
state0=POLL
state1=C1, ACPI HLT
```

原本存在的 C2/C3 不再暴露。

### 5. 启用 kdump

Fedora 44 已把 kdump 管理工具拆分到 `kdump-utils`；`kexec-tools` 本身只提供底层工具。

```bash
sudo dnf install kdump-utils
sudo kdumpctl reset-crashkernel --kernel=ALL
sudo systemctl enable kdump.service
sudo reboot
```

本机 13 GiB RAM 最终使用的启动参数为：

```text
crashkernel=2G-64G:256M,64G-:512M
```

重启后 kdump 状态：

```text
kdump.service: active (exited)
kexec: loaded kdump kernel
Starting kdump: [OK]
```

`active (exited)` 对 kdump 是正常状态，表示崩溃内核已经装载，不需要常驻进程。`No vmcore creation test performed` 仅表示尚未故意制造崩溃进行测试。

## 最终验证

### TuneD 和 CPU

```bash
systemctl is-enabled tuned-ppd.service
systemctl is-active tuned-ppd.service
tuned-adm active
cat /etc/tuned/profile_mode

for p in /sys/devices/system/cpu/cpufreq/policy*; do
    printf '%s boost=%s min=%s max=%s governor=%s epp=%s\n' \
      "${p##*/}" \
      "$(cat "$p/boost")" \
      "$(cat "$p/scaling_min_freq")" \
      "$(cat "$p/scaling_max_freq")" \
      "$(cat "$p/scaling_governor")" \
      "$(cat "$p/energy_performance_preference")"
done
```

最终确认值：

```text
tuned-ppd: masked / inactive
Current active profile: 6800h-stable
profile_mode: manual
boost: 0
scaling_min_freq: 2561000
scaling_max_freq: 3201000
energy_performance_preference: performance
```

### C-state 和内核参数

```bash
cat /proc/cmdline
cat /sys/devices/system/cpu/cpuidle/current_driver

for d in /sys/devices/system/cpu/cpu0/cpuidle/state*; do
    printf '%s name=%s desc=%s latency=%s\n' \
      "${d##*/}" \
      "$(cat "$d/name")" \
      "$(cat "$d/desc")" \
      "$(cat "$d/latency")"
done
```

应看到启动参数：

```text
processor.max_cstate=1 idle=nomwait
```

并且只有 `POLL` 与 `C1 (ACPI HLT)`。

### 睡眠和 kdump

```bash
systemd-analyze cat-config systemd/sleep.conf | \
  grep -E 'AllowSuspend|AllowHibernation|AllowSuspendThenHibernate|AllowHybridSleep'

systemctl is-enabled kdump.service
systemctl is-active kdump.service
sudo kdumpctl showmem
sudo kdumpctl status
```

## 再次崩溃后的取证

重启后立即执行：

```bash
sudo find /var/crash -maxdepth 3 -type f -ls
sudo journalctl -b -1 -k --no-pager | tail -n 300
journalctl --list-boots --no-pager
last -x --time-format iso | head -n 20
```

真正被 kdump 捕获的 panic 通常会在 `/var/crash/` 下生成 `vmcore` 和相关日志。

注意：kdump 能捕获进入内核 panic 处理流程的故障。如果 CPU 直接硬锁死、掉电或瞬间复位，第二崩溃内核可能来不及启动，因此仍可能没有 vmcore。下次屏幕出现 panic 时应同时拍摄完整堆栈，尤其是最上方错误类型和最下方 call trace。

## 回滚

### 恢复 TuneD 与 KDE 电源模式

```bash
sudo tuned-adm profile balanced
sudo systemctl unmask tuned-ppd.service
sudo systemctl enable --now tuned-ppd.service
```

### 恢复深度 C-state

```bash
sudo grubby --update-kernel=ALL \
  --remove-args="processor.max_cstate=1 idle=nomwait"
```

该项需要重启才生效。

### 恢复睡眠

```bash
sudo rm /etc/systemd/sleep.conf.d/99-disable-sleep.conf
sudo systemctl daemon-reload
```

### 禁用 kdump

```bash
sudo systemctl disable --now kdump.service
sudo grubby --update-kernel=ALL --remove-args="crashkernel"
```

移除 `crashkernel` 参数后需要重启才能释放预留内存。
