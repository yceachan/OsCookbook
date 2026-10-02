# Feat：左右 Shift 均切换 Rime 中英文，并取消状态冒泡

## 目标行为

- Fcitx5 始终保持 Rime 激活，不用 Shift 在 `keyboard-us` 与 Rime 之间切换。
- 单独短按左 Shift 或右 Shift，都切换 Rime 的 `ascii_mode`。
- 切换后不在输入框/光标附近显示“中”“abc”等状态冒泡。
- Shift 与其他按键组合时仍正常用于输入大写字母或快捷键。

## 1. 让左右 Shift 都由 Rime 处理

新建 `~/.local/share/fcitx5/rime/default.custom.yaml`：

```yaml
patch:
  "ascii_composer/switch_key/Shift_L": commit_code
  "ascii_composer/switch_key/Shift_R": commit_code
```

`commit_code` 的含义：

- 没有正在编辑的拼音时，短按 Shift 切换中文/英文模式。
- 正在编辑拼音时，先提交输入的原始编码，再切换模式。

如果希望正在组词时提交已经转换出的文字，可以改为 `commit_text`；如果不需要某个 Shift 切换，则设为 `noop`。

采用 `default.custom.yaml` 是为了让配置覆盖所有引用 `default.yaml` 的白霜方案，同时避免直接修改 Git 管理的上游文件。

## 2. 取消 Fcitx5 对 Shift 的抢占

Fcitx5 默认把左 Shift 放在“临时切换输入法”（`AltTriggerKeys`）中。若不清空，它会在 Rime 之前截获 Shift，产生两套切换逻辑。

在 `~/.config/fcitx5/config` 中设置：

```ini
[Hotkey]
AltTriggerKeys=
```

图形界面中的对应操作是：

1. 打开 Fcitx5 配置。
2. 进入“全局选项”。
3. 找到“临时切换输入法”。
4. 删除其中的左 Shift，保持为空。

`Ctrl+Space` 等真正的输入法启用/停用快捷键可以保留；这里只取消单独 Shift 的 Fcitx5 绑定。

## 3. 取消切换时的冒泡提示

继续在 `~/.config/fcitx5/config` 中设置：

```ini
[Behavior]
ShowInputMethodInformation=False
```

该选项控制“切换输入法/子模式时在光标附近显示输入法信息”。Rime 的 `ascii_mode` 变化会通知 Fcitx5 更新状态；关闭此项后，托盘状态仍会更新，但输入框附近不再弹出提示。

不要禁用 Classic UI，也不要关闭候选窗口；那会连正常候选词一起隐藏。

## 4. 应用配置

```bash
busctl --user call org.fcitx.Fcitx5 /controller \
  org.fcitx.Fcitx.Controller1 ReloadConfig

busctl --user call org.fcitx.Fcitx5 /controller \
  org.fcitx.Fcitx.Controller1 ReloadAddonConfig s rime
```

随后从 Fcitx5 菜单执行一次“重新部署”。若当前程序保存着旧的输入上下文，关闭并重新打开该程序后再测试。

## 5. 测试清单

在普通文本编辑器和 Chromium/Electron 应用中分别测试：

1. 中文状态输入 `ceshi`，应出现“测试”候选。
2. 单独按左 Shift，再输入 `test`，应直接得到英文。
3. 再按左 Shift，应回到中文。
4. 对右 Shift 重复上述步骤。
5. 按住 Shift 输入 `A`，应得到大写字母，不应触发模式切换。
6. 切换模式时不应出现输入框旁的状态冒泡。

## 6. 回滚

删除 `default.custom.yaml` 可恢复白霜原始的左 Shift/右 Shift 行为；在 Fcitx5 配置中重新给“临时切换输入法”绑定左 Shift，并把“切换输入法时显示输入法信息”打开，即可恢复 Fcitx5 默认行为。

## 原理来源

- [Fcitx5 全局快捷键和提示选项源码](https://github.com/fcitx/fcitx5/blob/master/src/lib/fcitx/globalconfig.cpp)
- [fcitx5-rime 模式变化和状态提示源码](https://github.com/fcitx/fcitx5-rime/blob/master/src/rimestate.cpp)
