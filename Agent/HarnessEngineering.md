# Harness Engineering：构建 AI 代理的工程化约束环境

> **核心定义**：Harness Engineering（驾驭工程）是将软件工程的重心从“编写代码”转移到“设计环境、制定规范和构建反馈循环”的新范式。通过构建一个高约束、高可观测性的“马具”（Harness），使 AI 代理（Agents）能够可靠、自主地完成复杂的软件开发任务。

---

## 1. OpenAI 实践：构建云原生 Agent 开发团队

OpenAI 的 Harness Engineering 旨在构建一个完全由 Agent 驱动的、可大规模并行的云原生软件开发体系。

### 1.1 核心架构：从“文档”到“上下文索引”

*   **`docs/` 目录 (唯一真理来源)**：
    *   **Spec-Driven**：所有开发活动由 `docs/` 内的规范文档驱动，包括产品需求、架构决策 (ADR) 和执行计划。
    *   **渐进式披露 (Progressive Disclosure)**：Agent 不会一次性读取所有信息。
*   **`AGENTS.md` (动态上下文索引)**：
    *   作为 Agent 的“任务入口”，提供到 `docs/` 深层文档的链接，引导 Agent 按需加载上下文。

### 1.2 并行与隔离：`git worktree` 即容器

*   **大规模并行**：利用 `git worktree`，为每个开发任务（新功能、Bug 修复）创建独立的文件系统快照。
*   **环境隔离**：每个 worktree 都拥有自己独立的、临时的可观测性堆栈（日志、指标），以及独立的测试数据库和应用实例。这使得成百上千的 Agent 可以 24/7 并行工作而互不干扰。

### 1.3 反馈循环与 AI 可观测性

*   **UI 可观测性 ("视觉")**：
    *   通过 **Chrome DevTools Protocol (CDP)**，Agent 能够直接获取 DOM 快照和截图，使其能像人类一样“看到”并验证 UI 变化。
*   **日志/指标可观测性 ("听觉")**：
    *   通过 **LogQL & PromQL** 查询接口，Agent 可以主动检索日志、分析性能指标，自主诊断问题。
*   **CI/CD 集成 (自主修复)**：
    *   Agent 能够监控 CI/CD 流程的状态。当构建失败时，它能自动抓取日志，分析错误，并提交新的 commit 进行修复。

### 1.4 Agent-to-Agent 协作模式

*   **Reviewer-Worker 模式**：
    *   Agent 提交的 PR 会触发另一个专职的 **Reviewer Agent** 进行代码审查。
    *   这个过程会一直循环，直到 Reviewer Agent 对代码质量满意为止，实现了完全自动化的 Code Review 流程。

### 1.5 熵增管理与“园丁”Agent (Maintenance & Gardening)

在大规模 Agent 自动生成代码的环境下，代码库会面临独特的“熵增”挑战。

*   **代码漂移 (Codebase Drift)**：
    *   Agent 具有极强的“模仿”倾向，它们会大量复制现有的代码模式。如果库中存在陈旧或次优的设计，Agent 会将其迅速扩散，导致架构逐渐偏离初衷。
*   **文档园丁 (Doc-Gardening Agents)**：
    *   OpenAI 部署了专门的 **“园丁 Agent”**，负责定期扫描 `docs/` 目录。
    *   **任务**：清理过时的设计文档、更新失效的文档链接、确保知识库与当前代码逻辑同步。
*   **黄金准则与重构 (Golden Principles & Refactoring)**：
    *   将架构规范和“品味（Taste）”硬编码为 **“黄金准则”**。
    *   后台任务会持续扫描代码库，一旦发现违背准则的模式，会自动由 Agent 发起定向重构的 PR。
*   **架构的机械执行**：
    *   通过自定义 Linter 和结构化测试，机械地强制执行分层架构。当 Agent 遇到由于架构约束导致的 Linter 报错时，错误信息会引导 Agent 自动修复违规代码。


### 1.6 高级工程哲学 (Advanced Philosophy)

*   **为了 AI 可读性而重写 (Re-implementation for Legibility)**：
    *   这是一个反直觉的决策：OpenAI 有时会选择**重新实现**某些功能，而不是直接使用现成的第三方库。
    *   **原因**：第三方库往往封装过度，对 Agent 来说是“黑盒”。自研的、逻辑显露的代码更容易被 Agent 理解、调试和维护。
*   **Linter 即教程 (Linting as Guidance)**：
    *   Linter 不仅仅是验证工具，更是 Agent 的**实时导师**。
    *   当 Agent 违反规则时，Linter 返回的不仅仅是 `Error`，而是包含**具体的修复建议**（Remediation Instructions）。Agent 读取这些建议后，能学会如何正确编码。
*   **修复 Harness，而非代码 (Fix the Harness, Not the Code)**：
    *   **黄金法则**：当 Agent 无法完成任务时，工程师**不应该**直接接手修复代码。
    *   **正确做法**：识别 Agent 缺失了什么能力（工具？文档？护栏？），然后**修复 Harness**。修复后，重启 Agent，让它**自己**去修复代码。这确保了系统的可扩展性。

---

## 2. LangChain 实践：构建可观测、可迭代的 Agent 运行时

### 2.1 核心架构：中间件与运行时护栏

*   **中间件模式**：在 Agent 的思考和执行链条中插入可编程的“钩子”，用于在运行时干预和引导 Agent。
*   **`LoopDetectionMiddleware` (防死循环)**：
    *   **逻辑**：监控 Agent 对同一文件或命令的重复操作。达到阈值后，强制 Agent “暂停并重新思考”，避免资源浪费。
*   **`PreCompletionChecklistMiddleware` (强制验证)**：
    *   **逻辑**：在 Agent 认为任务完成时进行拦截，强制其执行一个预设的验证清单（如运行测试、格式化代码），确保交付质量。
*   **`LocalContextMiddleware` (环境自动注入)**：
    *   **逻辑**：在 Agent 启动时，自动扫描工作目录、查找可用工具，并将这些信息注入到 System Prompt，降低 Agent 的“探索成本”。

### 2.2 Trace 驱动的迭代与优化

*   **Trace 一切**：使用 **LangSmith** 记录 Agent 的每一次思考、工具调用和环境反馈，形成完整的“思维链”记录。
*   **Manager-Worker 模式 (Trace 分析)**：
    *   一个 **Main Agent** 接收分析任务，然后分发给多个并行的 **Error Analysis Agents**。
    *   子 Agent 们负责从海量 Trace 中归纳失败模式，最后由 Main Agent 汇总成可行的改进方案（例如“为 Harness 增加一个新的中间件”或“优化某段 Prompt”）。

### 2.3 执行策略与计算预算优化

*   **推理三明治 (The Reasoning Sandwich)**：
    *   **Planning (最强模型)**：在任务规划阶段，使用能力最强的 LLM。
    *   **Implementation (高效模型)**：在具体的代码编写阶段，切换到成本更低、速度更快的高效模型。
    *   **Verification (最强模型)**：在最终的验证和审查阶段，再次切换回最强模型，确保结果的可靠性。

### 2.4 细节工程技巧 (Engineering Nuances)

*   **时间预算管理 (Time Budgeting)**：
    *   Agent 往往缺乏时间概念，容易在细枝末节上无限探索。
    *   **策略**：在 System Prompt 中注入倒计时或步骤限制警告。迫使 Agent 在资源耗尽前，主动从“发散探索模式”切换到“收敛验证模式”。
*   **上下文工程 (Context Engineering)**：
    *   将上下文构建视为一门专门的学科。这包括精心设计的目录结构、清晰的工具定义，以及将最佳实践（Best Practices）作为知识注入。
*   **非确定性测试处理 (Flaky Test Handling)**：
    *   由于 Agent 生成代码的非确定性，测试可能会变得不稳定（Flaky）。
    *   **策略**：不因一次测试失败就全盘否定。Harness 会自动执行重试逻辑，或者引导 Agent 编写更健壮的测试用例，而不是简单地阻塞流程。

---
*Reference: OpenAI "Harness Engineering" & LangChain "Improving Deep Agents with Harness Engineering"*
