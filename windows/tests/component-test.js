const assert = require("node:assert/strict");
const { catalog, render } = require("../src/renderer/components");

for (const item of catalog) {
  const html = render(item.id, {
    title: '<标题> & "文字"', content: "正文 <script>\n第二行", address: "https://example.com/?a=1&b=2", newWindow: true
  });
  assert.ok(html.includes(`data-html-studio-component="${item.id}"`));
  assert.ok(!html.includes("<script>"), item.id);
  assert.ok(!html.includes('<标题>'), item.id);
}
assert.match(render("link", { title: "链接", address: "#章节" }), /href="#章节"/);
assert.match(render("link", { address: "mailto:user@example.com", newWindow: true }), /rel="noopener noreferrer"/);
assert.match(render("button", { title: "按钮" }), /<button .*type="button"/);
assert.match(render("button", { address: "../page.html" }), /role="button" href="\.\.\/page.html"/);
assert.match(render("image", { address: "data:image/png;base64,AA==" }), /src="data:image\/png;base64,AA=="/);
assert.match(render("image", { address: "图片/a.png", title: '" onerror="x' }), /alt="&quot; onerror=&quot;x"/);
assert.throws(() => render("image", { address: "" }));
for (const address of ["javascript:alert(1)", "data:text/html,<script>", "java\nscript:alert(1)"]) {
  assert.throws(() => render("link", { address }));
  assert.throws(() => render("image", { address }));
}
console.log("HTML component tests passed (12 templates, portable styles, escaped fields and addresses).");
