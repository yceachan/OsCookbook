# Linux 托盘：GetLayout 返回错误的数据格式，读取菜单后连接断开

调用托盘菜单的 `GetLayout` 方法后，SDK 的 D-Bus 连接断开，右键菜单无法使用。
主程序仍在运行，但托盘服务名已经消失。
在 KDE 集成托盘时发现此问题，随后在独立 D-Bus 会话中复现。

测试提交为 `19453c4fcd87b4af2e424fef2708c08e907c2ab9`。
本机为 Fedora 44 x86_64、KDE Plasma 6.7.5、Wayland，桌面会话使用 dbus-broker 37。
最小复现使用 dbus-daemon 1.16.2，不需要 KDE、Qt 或其他应用。
构建环境为 Rust 1.98.1、Python 3.14.7、systemd 259。

## 最小复现

准备 Rust、Python 3、`busctl` 和 `dbus-run-session`。
获取测试提交，构建 FFI 动态库：

```sh
git clone https://github.com/UniDesktop/SDK.git
cd SDK
git checkout 19453c4fcd87b4af2e424fef2708c08e907c2ab9
cargo build --release --locked -p uda-ffi
```

把文末的脚本保存为仓库根目录下的 `repro-menu.py`。
在仓库根目录执行：

```sh
dbus-run-session -- python3 repro-menu.py
```

脚本只创建一个托盘和一个文本菜单项，然后调用 `GetLayout(0, -1, [])`。
独立会话没有桌面托盘宿主，桌面不会自动读取菜单。
因此，脚本可以直接触发并观察故障。

## 实际结果与预期结果

未修改的 SDK 输出：

```text
introspection: .GetLayout method iias u(ia{sv}a(ia{sv}v)v) -
GetLayout exit: 1
Call failed: Message recipient disconnected from message bus without replying
NameHasOwner: b false
```

`introspection` 行只省略了列间空格。
`NameHasOwner` 查询该托盘服务名是否仍有连接持有。
返回 `false` 时，该服务名已经消失。

预期是 `GetLayout` 成功返回菜单，托盘连接保持有效。
回复的 D-Bus 类型签名必须为 `u(ia{sv}av)`。类型签名描述消息中各字段的数据类型。
菜单节点包含 ID、属性字典和子节点数组。每个子节点以变体值返回，即同时包含类型和值的数据。
该格式见 [com.canonical.dbusmenu 接口定义（Waybar 仓库）](https://github.com/Alexays/Waybar/blob/master/protocol/dbus-menu.xml#L10-L16)。

## 源码与协议差异

[tray.rs](https://github.com/UniDesktop/SDK/blob/19453c4fcd87b4af2e424fef2708c08e907c2ab9/crates/uda-platform-linux/src/tray.rs#L319-L326) 把节点定义为四个字段，子节点数组也使用了不同的结构：

```rust
type MenuChildren = Vec<(i32, OwnedProps, zvariant::OwnedValue)>;
type MenuNode = (i32, OwnedProps, MenuChildren, zvariant::OwnedValue);
```

它对应的节点签名为 `(ia{sv}a(ia{sv}v)v)`，与接口要求的 `(ia{sv}av)` 不一致。
`root_node()` 和 `layout_node()` 还通过 [empty_variant()](https://github.com/UniDesktop/SDK/blob/19453c4fcd87b4af2e424fef2708c08e907c2ab9/crates/uda-platform-linux/src/tray.rs#L350-L367) 构造零字段结构 `()`。
[D-Bus 规范的容器类型章节](https://dbus.freedesktop.org/doc/dbus-specification.html#container-types) 明确禁止空结构。

[仓库内的协议文档](https://github.com/UniDesktop/SDK/blob/19453c4fcd87b4af2e424fef2708c08e907c2ab9/docs/internals/tray_specs.md#L117) 也记录了错误的 `GetLayout` 返回签名。
本次检查发现上述两项协议问题。对照修复同时处理了两项问题，未拆分验证各自的独立影响。

## 本机修复与验证

本机补丁把节点改为三个字段：

```rust
type MenuChildren = Vec<zvariant::OwnedValue>;
type MenuNode = (i32, OwnedProps, MenuChildren);
```

子节点以完整的 `(ia{sv}av)` 节点封装为变体值。
补丁删除 `empty_variant()`，并向调用方返回编码错误。
补丁还修正协议文档，增加节点类型签名及消息编码、解码的测试。

同一个复现脚本加载修复后的库时，输出：

```text
introspection: .GetLayout method iias u(ia{sv}av) -
GetLayout exit: 0
u(ia{sv}av) 1 0 0 1 (ia{sv}av) 1 4 "enabled" b true "label" s "Open" "type" s "standard" "visible" b true 0
NameHasOwner: b true
```

本机修复后的检查结果：

- `cargo check --workspace --all-targets` 通过。
- `./scripts/test-linux-mock.sh` 通过，Linux 测试共 82 项。
- `cargo test -p uda-ffi` 通过，FFI 测试共 89 项。

在 KDE 桌面上再次读取菜单后，托盘连接保持有效。
通过实际 D-Bus 菜单事件触发“显示歌词”和“隐藏歌词”，两个回调均成功。
本次实机验证覆盖 Linux，未验证 Windows。

<details>
<summary>复现脚本：repro-menu.py（只使用 Python 标准库和仓库自带绑定）</summary>

```python
"""Run from the SDK root, inside dbus-run-session. No desktop or Qt required."""
import os
from pathlib import Path
import subprocess
import sys
import time

sys.path.insert(0, str(Path.cwd() / "examples" / "python"))
from uda import Uda


def busctl(*arguments):
    return subprocess.run(
        ["busctl", "--user", "--", *arguments],
        capture_output=True, text=True, timeout=5,
    )


library = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("target/release/libuda_ffi.so").resolve()
with Uda(library) as uda:
    icon = uda.create_tray_icon("UDAMenuRepro", "Menu reproduction")
    menu = uda.create_tray_menu()
    menu.add_text("Open", lambda _item, _data: print("callback: Open", flush=True))
    icon.menu = menu
    prefix = f"org.kde.StatusNotifierItem-UDAMenuRepro-{os.getpid()}-"
    for _ in range(50):
        listing = busctl("list")
        if listing.returncode:
            raise RuntimeError(listing.stderr)
        services = [line.split()[0] for line in listing.stdout.splitlines() if line.startswith(prefix)]
        if services:
            service = services[0]
            introspection = busctl("introspect", service, "/MenuBar")
            if introspection.returncode == 0:
                break
        time.sleep(0.1)
    else:
        raise RuntimeError("Tray menu was not exported within 5 seconds")
    for line in introspection.stdout.splitlines():
        if "GetLayout" in line:
            print("introspection:", line.strip())
    result = busctl("call", service, "/MenuBar", "com.canonical.dbusmenu", "GetLayout", "iias", "0", "-1", "0")
    print("GetLayout exit:", result.returncode)
    print(result.stdout.strip() or result.stderr.strip())
    owner = busctl("call", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "NameHasOwner", "s", service)
    if owner.returncode:
        raise RuntimeError(owner.stderr)
    print("NameHasOwner:", owner.stdout.strip())
```

</details>
