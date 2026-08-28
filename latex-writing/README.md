# LaTeX 中文论文项目

这是一个从 LaTeX 源码直接生成 PDF 的中文论文项目。XeLaTeX 负责排版，Biber 负责参考文献；VS Code 与 LaTeX Workshop 提供编辑、自动编译、PDF 预览、日志跳转和 SyncTeX 定位。

## 1. 当前环境

| 层级 | 工具 | 当前版本 | 职责 |
|---|---|---:|---|
| 终端 | PowerShell (`pwsh`) | 7.6.0 | 执行 CLI 和构建脚本 |
| 编辑器 | Visual Studio Code | 1.135.0 | 编辑源码、查看日志和 PDF |
| VS Code 扩展 | LaTeX Workshop | 10.18.0 | 调用编译命令、预览、SyncTeX |
| LaTeX 发行版 | MiKTeX | 25.12 | 提供引擎、宏包和字体配置 |
| 编译引擎 | XeLaTeX | MiKTeX-XeTeX 4.16 | 将 UTF-8 `.tex` 排版为 PDF |
| 文献工具 | Biber | 2.21 | 读取 `.bib` 并生成文献内容 |

新开一个 PowerShell 终端后检查命令：

```powershell
pwsh --version
code --version
xelatex --version
biber --version
```

若安装后尚未重启终端，可临时补入 MiKTeX：

```powershell
$env:Path += ";$env:LOCALAPPDATA\Programs\MiKTeX\miktex\bin\x64"
```

## 2. 快速开始

```powershell
cd C:\Eachan\Workspace\latex-writing
code .
pwsh .\build.ps1
```

最终文件：

```text
output/pdf/main.pdf
```

清理全部生成物：

```powershell
pwsh .\build.ps1 -Clean
```

指定其他主文件：

```powershell
pwsh .\build.ps1 -Main thesis.tex
```

## 3. 完整工具链

```text
main.tex + figures/* + references.bib
                    │
                    ▼
              XeLaTeX 第 1 遍
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
  output/pdf/main.pdf   build/main.aux + main.bcf
                              │
                              ▼
                            Biber
                              │
                              ▼
                       build/main.bbl
                              │
                              ▼
                     XeLaTeX 第 2、3 遍
                              │
                              ▼
               编号、引用、目录稳定的 main.pdf
```

第一遍 XeLaTeX 排版正文，并收集章节、图表、公式和文献请求。Biber 根据 `main.bcf` 和 `references.bib` 生成 `main.bbl`。后两遍 XeLaTeX 插入文献，并稳定交叉引用、目录页码和 PDF 书签。

## 4. 原始 CLI：不经过脚本

在项目根目录运行：

```powershell
New-Item -ItemType Directory -Force build, output/pdf

xelatex `
  -synctex=1 `
  -interaction=nonstopmode `
  -file-line-error `
  -aux-directory=build `
  -output-directory=output/pdf `
  main.tex

biber `
  --input-directory=build `
  --output-directory=build `
  main

xelatex -synctex=1 -interaction=nonstopmode -file-line-error -aux-directory=build -output-directory=output/pdf main.tex
xelatex -synctex=1 -interaction=nonstopmode -file-line-error -aux-directory=build -output-directory=output/pdf main.tex
```

参数说明：

- `-synctex=1`：生成源码与 PDF 的位置映射。
- `-interaction=nonstopmode`：遇到错误时继续输出完整日志。
- `-file-line-error`：错误显示为 `文件:行号`。
- `-aux-directory=build`：把中间产物放进 `build/`。
- `-output-directory=output/pdf`：把 PDF 放进交付目录。
- `biber main` 使用基本名，不带 `.tex`。

没有参考文献时可省略 Biber；为了稳定 `\ref`、目录和图表编号，XeLaTeX 通常仍需运行两遍。

## 5. `build.ps1` 构建流

脚本只是固定顺序调用上面的 CLI：

1. 从 PATH 定位 `xelatex` 和 `biber`；若当前终端 PATH 未刷新，则使用 MiKTeX 用户安装路径。
2. 删除根目录可能遮蔽新结果的旧辅助文件。
3. 创建 `build/` 与 `output/pdf/`。
4. 执行第一遍 XeLaTeX。
5. 检测到 `build/main.bcf` 时执行 Biber。
6. 再执行两遍 XeLaTeX。
7. 确认 `output/pdf/main.pdf` 已生成，否则返回失败。

`-Clean` 会删除 `build/`、`output/` 和根目录遗留的 LaTeX 生成物，不会删除 `.tex`、`.bib`、图片或编辑器配置。

## 6. VS Code LaTeX Workshop

### 打开项目

必须打开整个项目目录，而不是只打开一个 `.tex` 文件：

```powershell
code C:\Eachan\Workspace\latex-writing
```

扩展读取 `.vscode/settings.json`，使用以下 recipe：

```text
xelatex → biber → xelatex → xelatex
```

这些仍是原生 CLI，LaTeX Workshop 只负责按顺序调用。

### 自动编译

当前配置为保存时编译：

```json
"latex-workshop.latex.autoBuild.run": "onSave"
```

编辑并保存 `main.tex` 后，状态栏会显示构建状态，生成结果写入 `output/pdf/main.pdf`。

### 手动编译与选择 recipe

按 `Ctrl+Shift+P`，使用：

```text
LaTeX Workshop: Build LaTeX project
LaTeX Workshop: Build with recipe
```

第二条命令会让你明确选择 `xelatex -> biber -> xelatex x2`。

也可以按 `Ctrl+Shift+B` 执行工作区任务“论文：生成 PDF”，该任务调用 `pwsh ./build.ps1`。

### 查看 PDF

按 `Ctrl+Shift+P`：

```text
LaTeX Workshop: View LaTeX PDF file
```

当前配置使用 VS Code 标签页内置查看器。PDF 不会写回源码，只是读取 `output/pdf/main.pdf`。

### 正向 SyncTeX：源码跳到 PDF

把光标放在 `.tex` 的目标行，执行：

```text
LaTeX Workshop: SyncTeX from cursor
```

扩展读取 `main.synctex.gz`，在 PDF 中跳到对应位置。

### 反向 SyncTeX：PDF 跳到源码

在 LaTeX Workshop 的 PDF 查看器中对正文执行双击或 `Ctrl+单击`；不同版本的默认鼠标组合可能略有差异。成功后编辑器会跳回对应 `.tex` 行。

如果定位失效，确认编译参数包含 `-synctex=1`，并重新完整编译。

### 查看编译日志

打开 VS Code 的“输出”面板，在下拉框中选择：

```text
LaTeX Compiler
LaTeX Workshop
```

带 `-file-line-error` 的错误通常显示为：

```text
main.tex:123: Undefined control sequence.
```

点击文件位置即可跳到相关行。完整日志位于 `build/main.log`。

### 清理生成物

`Ctrl+Shift+P` 中可使用 LaTeX Workshop 的清理命令；本项目更推荐运行统一任务：

```text
Terminal → Run Task → 论文：清理生成物
```

它对应：

```powershell
pwsh .\build.ps1 -Clean
```

## 7. LaTeX 语法段速览

### 文档骨架

```latex
\documentclass[UTF8,zihao=-4]{ctexart}

\title{论文标题}
\author{作者姓名}
\date{\today}

\begin{document}
\maketitle
正文。
\end{document}
```

`\documentclass` 与 `\begin{document}` 之间是导言区，用于加载宏包、字体和全局版式。

### 章节与段落

```latex
\section{一级标题}
\subsection{二级标题}
\subsubsection{三级标题}

普通段落之间留一个空行。

这是新的段落。
```

不要用连续空格或回车模拟版式。

### 字号、行距与缩进

```latex
{\zihao{5} 五号文字}
{\fontsize{10.5pt}{16pt}\selectfont 精确字号与基线间距}

\setstretch{1.5}
\setlength{\parindent}{2em}
\setlength{\parskip}{0pt}
\noindent 这一段取消首行缩进。
```

### 对齐与强调

```latex
\begin{center}居中内容\end{center}
\begin{flushleft}左对齐内容\end{flushleft}
\begin{flushright}右对齐内容\end{flushright}

\textbf{粗体}
\emph{强调}
\texttt{等宽字体}
```

### 列表与特殊字符

```latex
\begin{itemize}
  \item 无序条目
\end{itemize}

\begin{enumerate}
  \item 有序条目
\end{enumerate}

\% \_ \& \# \{ \}
```

### 数学公式

```latex
行内公式 $E=mc^2$。

\begin{equation}
  f(x)=\int_{-\infty}^{\infty}\hat f(\xi)e^{2\pi i x\xi}\,\mathrm{d}\xi
  \label{eq:fourier}
\end{equation}

如式~\eqref{eq:fourier} 所示。
```

### 单图

```latex
\begin{figure}[htbp]
  \centering
  \includegraphics[width=0.8\linewidth]{figures/result.pdf}
  \caption{实验结果}
  \label{fig:result}
\end{figure}

如图~\ref{fig:result} 所示。
```

### 并排子图

```latex
\begin{figure}[htbp]
  \centering
  \begin{subfigure}[t]{0.48\linewidth}
    \centering
    \includegraphics[width=\linewidth]{figures/a.pdf}
    \caption{方法 A}
  \end{subfigure}\hfill
  \begin{subfigure}[t]{0.48\linewidth}
    \centering
    \includegraphics[width=\linewidth]{figures/b.pdf}
    \caption{方法 B}
  \end{subfigure}
  \caption{方法对比}
  \label{fig:comparison}
\end{figure}
```

`[htbp]` 依次建议当前位置、页顶、页底和浮动页。双栏模板中，`figure` 占一栏，`figure*` 跨两栏。

### 表格

```latex
\begin{table}[htbp]
  \centering
  \caption{实验结果}
  \label{tab:result}
  \begin{tabular}{lcc}
    \toprule
    方法 & 准确率 & 耗时 \\
    \midrule
    A & 92.1\% & 10 ms \\
    B & 94.3\% & 14 ms \\
    \bottomrule
  \end{tabular}
\end{table}
```

### 文献引用

`references.bib`：

```bibtex
@book{knuth1984,
  author    = {Donald E. Knuth},
  title     = {The TeXbook},
  year      = {1984},
  publisher = {Addison-Wesley}
}
```

正文：

```latex
经典文献~\cite{knuth1984}。
\printbibliography
```

## 8. 项目与源码产物 Layout

```text
latex-writing/
├─ .vscode/
│  ├─ settings.json       # LaTeX Workshop 原生 CLI recipe
│  └─ tasks.json          # VS Code 构建与清理任务
├─ figures/               # PDF、PNG、JPEG 等论文图片
├─ build.ps1              # XeLaTeX/Biber/XeLaTeX/XeLaTeX
├─ main.tex               # 主文档和排版配置
├─ references.bib         # BibLaTeX 文献数据库
├─ README.md              # 环境、CLI、扩展和语法说明
├─ build/                 # 中间产物，可随时删除
│  ├─ main.aux            # 章节、图表、公式和交叉引用
│  ├─ main.bcf            # Biber 控制文件
│  ├─ main.bbl            # Biber 生成的文献内容
│  ├─ main.blg            # Biber 日志
│  ├─ main.log            # XeLaTeX 完整日志
│  ├─ main.out            # PDF 书签等辅助数据
│  └─ main.run.xml        # Biber 运行信息
└─ output/
   └─ pdf/
      ├─ main.pdf         # 最终交付文件
      └─ main.synctex.gz  # 编辑器正反向定位数据
```

`build/`、`output/` 和 `tmp/` 已加入 `.gitignore`，不会污染源码历史。

## 9. 排错

- `MiKTeX ... have not checked for updates`：打开 MiKTeX Console 执行更新检查；它是环境维护提示，不代表本次 PDF 构建失败。
- `requested release ... only release ... available`：宏包与 LaTeX 内核版本不同步，先在 MiKTeX Console 更新全部组件，再重新构建。
- `xelatex` 找不到：重启终端，或检查 MiKTeX 的 `bin\x64` 是否位于用户 PATH。
- `File 'xxx.sty' not found`：在 MiKTeX Console 安装缺失宏包，并检查自动安装设置。
- `Citation ... undefined`：先运行 XeLaTeX，再运行 Biber，最后运行两遍 XeLaTeX。
- `Reference ... undefined`：再运行一次 XeLaTeX，并检查 `\label` 名称。
- `Overfull \hbox`：检查 `build/main.log` 指向的长文本、URL、代码或公式。
- 图片找不到：从项目根目录检查相对路径，例如 `figures/result.pdf`。
- PDF 不更新：确认查看的是 `output/pdf/main.pdf`，再执行一次清理与完整构建。

投稿时优先使用期刊、会议或学校提供的官方 `.cls/.sty` 和示例文件，并按官方要求调整编译引擎或文献步骤。
