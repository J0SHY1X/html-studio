# 第三方组件与素材

仓库根目录的 MIT 许可证适用于 HTML Studio 项目代码；它不替换依赖及操作系统组件的许可证。

- Windows 运行时使用 [Electron](https://github.com/electron/electron)，并包含 Chromium、Node.js 及其他第三方组件。便携发行包保留 `LICENSE.electron.txt` 和 `LICENSES.chromium.html`；再分发时不要移除。
- Windows 的 DOCX 导出使用 [docx](https://github.com/dolanmiu/docx)，声明为 MIT。其他直接与传递依赖的确切版本在 `windows/package-lock.json` 中。
- Windows 构建工具包括 electron-builder 等；通过 npm 安装，各自许可证随包提供。
- Mac 版使用系统 AppKit、SwiftUI、WebKit 等框架。可选外部转换器 [Pandoc](https://github.com/jgm/pandoc) 并未打包进应用，由用户单独安装并遵循其许可证。
- 图标为本项目使用 AI 辅助生成并经本地脚本处理的素材。仓库保留图标母版与转换工具；重新运行 Python 图标工具需要单独安装 Pillow。

应用可打开的用户 HTML、文档、图片、字体等不属于本仓库的许可范围。请自行确认这些内容的再分发权限。
