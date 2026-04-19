# 现代 Web 架构的三层边界：从客户端到 API 服务

> [!note]
> **Ref:** 本文档全面重构了对前端部署环境的认知，从宏观角度划分了**客户端浏览器内核**、**Page-Server (静态资源服务器)** 和 **后端 API 服务** 的职能边界，并深入探讨了浏览器安全沙箱与纯本地环境的妥协方案。

## 1. 架构全景：三层角色的职能划分

在现代前后端分离的 SPA 架构中，系统通常被物理隔离为三个核心角色：

### 1.1 客户端浏览器内核 (Browser Engine)
**角色定位**：前台展示厅与用户交互中心。
**物理位置**：用户的设备（占用客户端 CPU/GPU）。
**核心职责**：
- **UI 渲染与反馈**：解析 HTML/CSS，利用 GPU 将 DOM 树栅格化为像素。
- **状态与逻辑托管**：运行 React/Vue 框架的 JS 运行时，执行轻量级业务逻辑（格式校验、表单响应等），并计算 Virtual DOM Diff 更新视图。
- **SPA 路由控制**：拦截 URL 变化，使用 JS 动态挂载/卸载组件，避免页面整体刷新。
- **网络代理**：通过 `fetch`/`XHR` 向后端索要业务数据。

### 1.2 Page-Server (静态资源服务器)

```bash
 HTTP  2026年4月20日 上午1:49:49 ::1 GET /assets/chunks/c4Diagram-AHTNJAMY.CFeEoS68.js
 HTTP  2026年4月20日 上午1:49:49 ::1 Returned 200 in 1 ms
 HTTP  2026年4月20日 上午1:49:49 ::1 GET /assets/chunks/blockDiagram-DXYQGD6D.C1yNOEXd.js
 HTTP  2026年4月20日 上午1:49:49 ::1 Returned 200 in 1 ms
 HTTP  2026年4月20日 上午1:49:49 ::1 GET /assets/chunks/baseUniq.BxeUNvnd.js
```

**角色定位**：物资分发仓库（如 Nginx, Vercel, 阿里云 OSS/CDN）。
**物理位置**：云端机房边缘节点。
**核心职责（极度被动）**：

- **静态资产分发**：迅速响应客户端请求，将 `npm run build` 打包好的 HTML/JS/CSS 原封不动地下发。
- **SPA 路由 Fallback (黑洞重定向)**：当用户直接通过 URL 访问深层路由（如 `/user/profile`）时，由于物理路径下无对应文件，Page-Server 会配置规则（如 Nginx 的 `try_files`）将流量强制重定向回根目录的 `index.html`，把解析权交还给客户端 JS 框架。
- **强缓存策略制定**：为带有 Hash 后缀的静态资产设置长达一年的 `Cache-Control` 响应头。

### 1.3 后端 API 服务 (Backend API Server)
**角色定位**：核心中央厨房与绝对真理库（如 Spring Boot, Go, Node.js）。
**物理位置**：企业内网安全隔离的服务器集群。
**核心职责**：
- **核心业务验证**：处理诸如支付、扣减库存等涉及金额/安全的逻辑。绝不信任客户端传来的任何数据。
- **持久化与数据过滤**：作为唯一可以直接连接数据库（MySQL/Redis）的角色，处理复杂 SQL 查询，剔除敏感字段后组装为 JSON 吐给前端。
- **身份鉴权 (Auth)**：核发 JWT Token 并严格校验每次 API 调用的权限。

---

## 2. 为什么不能直接双击 `index.html` 运行？

这是初学者的核心疑惑：既然 `dist` 里面全是静态资产，为什么不能在本地通过 `file:///` 协议双击打开，而非要放置在 Page-Server 上？

这是因为现代前端应用高度依赖 Web 服务器提供的协议栈。直接双击会遭遇三大致命阻击：

### 2.1 浏览器沙箱与 CORS 限制
**原因**：浏览器的严苛限制是为了**保护本地硬盘不被恶意脚本偷空**（防止恶意 HTML 中的 JS 通过 `file:///` 读取本地密码文件并发送到公网）。
**后果**：浏览器处于“最不信任”模式，坚决禁止通过 `file:///` 协议加载 ES Modules (Vite 默认产物保留 `<script type="module">`)，并无情拦截所有试图访问本地文件的 Fetch 请求（报 CORS 错误）。

### 2.2 绝对路径灾难 (Absolute Paths)
构建工具默认应用部署在域名的**根目录**，注入的路径多为绝对路径：`<link rel="stylesheet" href="/assets/index.css">`。
- **Web 环境**：解析为 `http://example.com/assets/index.css`（正确）。
- **本地双击**：解析为 `file:///C:/assets/index.css`，直接去操作系统的根目录找，导致大面积 404 文件丢失。

### 2.3 SPA 路由 404 黑洞
- **F5 刷新 / 直接访问**：在 History 路由模式下，刷新 `file:///C:/dist/index.html/user/profile` 时，浏览器会真实地去寻找操作系统中的对应目录。因为没有 Page-Server 提供 `try_files` 兜底重定向，会直接报错找不到文件。

---

## 3. 若非要“本地纯环境运行”，需要哪些妥协？

要将现代前端工程退化为“绿色双击免安装版”，必须进行“降维打击”：

1. **解决路径问题（降维为相对路径）**：
   在打包配置（如 `vite.config.js`）中强制使用相对路径引用：`base: './'`。
2. **解决路由 404（降维为 Hash 路由）**：
   将 Vue/React Router 改为 **Hash 模式**。URL 变为 `file:///C:/dist/index.html#/user/profile`。
   **原理**：浏览器在寻找本地文件时，会安全地忽略 `#` 及其后的内容，从而老老实实加载基准的 `index.html` 文件，后续解析交由 JS 完成。

---

## 4. 现代桌面端/本地化开发的最佳实践 (Desktop Web)

在真正的工程界，如果需要将 Web 应用作为本地软件交付给终端用户，主流做法是使用 **双进程模型架构 (Dual-Process Model)**，如 **Electron** 或 **Tauri**。

- **渲染进程 (Renderer)**：被沙箱锁定的 Vue/React 网页界面。
- **主进程 (Core)**：打包在内的 Node.js 或 Rust 环境，拥有操作系统的**最高权限**。
- **IPC 通信**：前端界面需要读取本地文件时，不能自己干，而是向主进程发送 IPC 消息请求代办（这与前端向后端 API 服务器发请求的架构思想如出一辙）。

这不仅完美绕过了 `file:///` 的所有安全限制，还彻底打通了 Web 技术栈与底层操作系统的隔阂。