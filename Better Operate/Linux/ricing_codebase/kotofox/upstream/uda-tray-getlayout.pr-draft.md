在kde plama 6.7 DE下，调用 Linux 托盘菜单的 `GetLayout` 后，原版 SDK 的 D-Bus 连接断开，右键菜单无法使用。修复版返回标准菜单结构，读取菜单后仍能接收点击事件。

充要讨论和修复方式已在 #2 提出。

## 修改

菜单节点改为 `(ia{sv}av)`，包含 ID、属性字典和子节点数组。每个子节点以完整节点封装为变体值。变体值同时包含类型和值。

删除构造空结构 `()` 的代码。D-Bus 规范禁止空结构。节点编码失败时，`GetLayout` 返回 D-Bus 错误。

修正 `docs/internals/tray_specs.md` 中的返回签名。此次修改只涉及 Linux 菜单编码、相关测试和协议文档。没有修改公开 Rust API 或 C ABI。



## 回归测试

新增类型签名及消息编码、解码测试。另一个测试通过独立客户端和服务端，在真实会话总线上调用 `GetLayout`。该测试覆盖未挂菜单、空菜单和含子菜单的菜单。它还读取嵌套节点，并发送点击事件，确保回调执行。

把同一个总线测试加入未修复的基线提交后，测试失败，错误为：

```text
org.freedesktop.DBus.Error.NoReply
Message recipient disconnected from message bus without replying
```

修复后，该测试通过。Issue 中的 Python 最小复现脚本也通过，返回签名为 `u(ia{sv}av)`，`NameHasOwner` 返回 `true`。

ci：

- `cargo check --workspace --all-targets`。
- `./scripts/test-linux-mock.sh`，83 项 Linux 测试通过。
- `cargo test -p uda-ffi`，89 项 FFI 测试通过。
- `cargo fmt --all -- --check`。
- `cargo clippy --workspace --all-targets -- -D warnings`。
- `cargo build --release --locked -p uda-ffi`。

## KDE 端到端验证

我使用uda 在fedora，kde plasma 下开发了一款集成开源musicfox tui播放器，kotonaho桌面歌词hud的管理器kotofox.

改用fixup commit后，托盘菜单正确读取，通过 D-Bus 菜单点击事件显示、隐藏桌面歌词。再通过菜单关闭、重新打开 Konsole等操作均成功。

补充修复：托盘 `Menu` 属性从字符串类型 `s` 改为对象路径类型 `o`。总线测试先读取该属性，再用返回的路径调用 `GetLayout`。在 KDE 实际右键托盘图标后，13 个菜单项正常显示。
