> [!note]
>
> [为typora更换更新版本的mermaid避免图表无法加载 | ErgouTree's Blog](https://www.ergoutreegal.cn/posts/23249.html)

基于这篇参考博客，走npm 安装本地mermaid，注入typora js lib 的路线.

不同版本号，typora Resource 有差异，故我的实际环境与博客有出入

-verison :1.9.5 (lastest easy to hacked)



```bash
npm search  mermaid  
npm install mermaid @mermaid/mermaid-cli

#everything ,search <package>/dist , found mermaid.min.js
```

1. **安装 asar 工具**：asar 是一个用于处理 Electron 应用资源文件的工具，Typora 就是基于 Electron 开发的。在终端中输入命令`sudo npm install -g asar`来全局安装 asar 工具。安装过程中可能需要输入系统密码，按照提示操作即可。
2. **下载 Mermaid 新版本**：确定你想要下载的 Mermaid 版本，Mermaid 版本更新较快，可以在 Mermaid 官方网站查看最新版本信息。例如，若要下载 10.9.0 版本，在终端中输入命令`npm install mermaid@10.9.0`，这会在当前目录下创建一个`node_modules`文件夹，并将 Mermaid 的 10.9.0 版本下载到该文件夹中。
3. **解压 Typora 的 lib.asar 文件**：Typora 的资源文件被打包在`lib.asar`文件中，我们需要解压它来替换其中的 Mermaid 文件。进入 Typora 的安装目录，在终端中输入命令`asar extract lib.asar extracted`，这会在安装目录下创建一个名为`extracted`的文件夹，里面包含了解压后的 Typora 资源文件。
4. **替换新版 Mermaid 的 js 文件**：进入`extracted\resources\app\lib\diagram`目录（不同版本路径可能略有差异），这里面有 Typora 自带的`mermaid.min.js`文件。将我们前面下载的 Mermaid 新版本的`mermaid.min.js`文件复制到这个目录，并覆盖原文件。为了以防万一，你可以先备份原文件，例如使用命令`mv mermaid.min.js mermaid.min.js.bak`（在 Linux 系统下）。
5. **修改 frame.js 接入 Mermaid 的文件路径**：在`extracted\resources\app\renderer`目录下找到`frame.js`文件，使用文本编辑器打开它。在文件中找到类似`const n = path.join(app.getAppPath(), '.', 'lib', 'diagram','mermaid.min.js');`的语句，将其修改为`const n = path.join(app.getAppPath(), 'lib', 'diagram','mermaid.min.js');` 。这样修改后，Typora 就会默认使用我们替换后的`lib`路径下的 Mermaid 文件。好处是后续如果想要使用更新版本的 Mermaid，直接替换`lib/diagram`下的`mermaid.min.js`文件即可。
6. **重新打包 lib.asar 文件**：完成上述修改后，需要将`extracted`文件夹重新打包回`lib.asar`文件。在终端中，确保当前目录是 Typora 的安装目录，然后输入命令`asar pack extracted lib.asar` 。这会将修改后的资源文件重新打包成`lib.asar`文件。
7. **替换原 lib.asar 文件**：备份原`lib.asar`文件，例如`mv lib.asar lib.asar.old`，然后将新生成的`lib.asar`文件移动到原来的位置。此时再打开 Typora，就会使用更新后的 Mermaid 版本了。