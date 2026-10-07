# Typora Ea Reader

本机 Typora 1.9.3 的亮色主题原型，位于 OsCookbook 的 `ricing_linux` 分支。保留 reader 的米白底色、砖红强调色、字体层次和流动正文宽度，并适配代码块、任务列表、GitHub alerts、YAML 属性和 Mermaid。

## 样式来源

- `/home/pi/work/ea-md-reader/src/markdown.css` 与 `src/app.css`：只读输入，阅读样式的唯一来源。
- `src/typora.css`：Typora 编辑器适配。
- `src/ea-reader.user.css`：本机个人 PDF 分页规则，从原 GitHub 主题迁移。
- `scripts/build-theme.mjs`：转换 reader 选择器，并将 Shiki 的 GitHub Light 调色板映射到 CodeMirror。
- `dist/`：生成产物，不手工编辑，不纳入版本管理。

依赖在本目录安装；构建和配置不会写入 reader 工作区。当前读取本机 reader 的固定路径，尚未扩展为跨机器安装方案。

## 构建与更新

在本目录执行：

```sh
npm ci
npm run build
cp dist/ea-reader.css dist/ea-reader.user.css /home/pi/.config/Typora/themes/
```

本机已将默认主题设为 `ea-reader.css`。下次启动 Typora 时生效；也可从「主题」菜单选择 **Ea Reader**。原 GitHub 主题仍保留，配置备份位于 `/home/pi/.config/Typora/backups/ea-reader-20261006-152837782/`。

`:::callout` 是 reader 的解析器扩展，CSS 不会为 Typora 添加该语法；需要使用 GitHub alerts。字体按本机已安装字体选择。

## 验证

使用本机 Typora 的基础 CSS 检查了 1200px 与 390px 视口：页面没有横向溢出，图表在容器内滚动；正文为 16px、行高为 29.12px，代码为 13px。字号调整、任务复选框及个人 PDF 分页规则通过浏览器预览检查。未进行 Typora 原生窗口的编辑交互测试。

MIT，见 `LICENSE`。
