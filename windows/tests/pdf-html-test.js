const assert = require("node:assert/strict");
const {
  preparedPDFHTML,
  waitForPrintReadiness,
  withStageTimeout
} = require("../src/pdf-export");

const source = `<!doctype html>
<html><head><style>.chapter { break-after: page; }</style></head>
<body><section class="chapter"><h1>标题</h1><p>正文</p>
<img loading="lazy" src="cover.png"><img loading=lazy src="tail.png">
</section></body></html>`;

const result = preparedPDFHTML(source, "file:///C:/Documents/");

assert.match(result, /data-html-studio-pdf/);
assert.match(result, /break-inside: avoid !important/);
assert.match(result, /page-break-inside: avoid !important/);
assert.match(result, /thead \{ display: table-header-group; \}/);
assert.match(result, /\[data-page-break-allow\]/);
assert.match(result, /\.chapter \{ break-after: page; \}/);
assert.match(result, /<base href="file:\/\/\/C:\/Documents\/">/);
assert.doesNotMatch(result, /loading\s*=\s*["']?lazy/i);
assert.match(result, /loading="eager"/);
assert.match(result, /loading=eager/);

async function main() {
  const readinessStart = Date.now();
  await waitForPrintReadiness({ isDestroyed: () => false });
  assert.ok(
    Date.now() - readinessStart < 1_500,
    "确定性布局等待不应永久阻塞"
  );

  await assert.rejects(
    withStageTimeout(new Promise(() => {}), 20, "单元测试"),
    (error) => error.code === "PDF_RENDER_TIMEOUT" && /单元测试/.test(error.message)
  );

  console.log("HTML Studio Windows PDF print HTML tests passed.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
