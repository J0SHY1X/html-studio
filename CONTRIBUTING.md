# 贡献指南

感谢参与 HTML Studio。提交问题或修改前，请说明影响的是 Mac、Windows 还是两端，并提供系统版本、应用版本和不含隐私的最小 HTML 样例。

## 开发验证

macOS：

```sh
cd macos
swift build
swift run HTMLStudioSmokeTests
```

Windows：

```sh
cd windows
npm ci
npm test
```

修改编辑器时，请检查中文输入法、选区/焦点、撤销/重做、剪切后继续输入、纯文本/富文本粘贴和多标签切换。修改导出/打印时，请检查中文长文、表格、强制分页和文档末尾内容。

两端为独立实现，修复一端后请说明另一端是否需要对应调整。不要提交 `node_modules`、`.build`、`dist`、草稿、日志、真实业务文档或访问令牌。请将功能修改与格式化分开，并在 PR 中写明验证步骤及尚未测试的系统。

提交的贡献将按仓库 MIT 许可证分发；请确保有权提交所包含的代码与素材，并保留第三方声明。
