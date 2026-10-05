const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { filePathsFromArguments } = require("../src/file-launch");

const context = { window: {} };
vm.runInNewContext(fs.readFileSync(path.join(__dirname, "../src/renderer/converters.js"), "utf8"), context);
const convert = context.window.HTMLStudioConverters.markdownToHTML;

const markdown = [
  "# 表格测试",
  "",
  "| 名称 | 数量 | 备注 |",
  "| :--- | ---: | :---: |",
  "| **项目 A** | 12 | `a|b` |",
  "| 转义 \\| 竖线 | 3 | <script> |",
  "| 短行 | 1 |",
  "",
  "## 表格之后",
  "",
  "```md",
  "| 代码 | 示例 |",
  "| --- | --- |",
  "```"
].join("\n");
const html = convert(markdown);
assert.equal((html.match(/<table>/g) || []).length, 1, "代码块内不应生成表格");
assert.equal((html.match(/<th[ >]/g) || []).length, 3);
assert.equal((html.match(/<td[ >]/g) || []).length, 9, "短行应补齐缺失列");
assert.match(html, /<strong>项目 A<\/strong>/);
assert.match(html, /<code>a\|b<\/code>/);
assert.match(html, /转义 \| 竖线/);
assert.match(html, /&lt;script&gt;/);
assert.match(html, /text-align: right/);
assert.match(html, /text-align: center/);
assert.match(html, /border-collapse: collapse/);
assert.match(html, /th, td \{ border:/);
assert.match(html, /<h2>表格之后<\/h2>/);
assert.match(convert("A | B\r\n--- | ---\r\n1 | 2"), /<table>/);
assert.doesNotMatch(convert("A | B\n--- | invalid\n1 | 2"), /<table>/);
assert.match(convert("```\nunclosed <code>"), /unclosed &lt;code&gt;<\/code><\/pre>/);

assert.deepEqual(filePathsFromArguments(["app.exe", "--inspect", "文档.html", "文档.html", "table.MD", "script.js"], __dirname), [
  path.resolve(__dirname, "文档.html"), path.resolve(__dirname, "table.MD")
]);
console.log("HTML Studio document conversion and file launch regression tests passed.");
