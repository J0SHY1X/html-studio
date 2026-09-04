const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const { app } = require("electron");
const { exportHTMLToPDF } = require("../src/pdf-export");

const outputPath = path.join(os.tmpdir(), "html-studio-windows-pdf-test.pdf");
const logPath = path.join(os.tmpdir(), "html-studio-windows-pdf-test.log");
const html = `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><style>
@page { size: A4; margin: 14mm; }
body { font: 18px/1.6 "Microsoft YaHei", "PingFang SC", sans-serif; color: #172033; }
.page { break-after: page; }
.box { padding: 24px; background: #fff2a8; border: 2px solid #e5a400; }
.reserved { height: 690px; border: 2px dashed #adc7dd; background: #f7fbff; padding: 16px; }
.crossing { margin: 24px 0; padding: 18px; border-left: 6px solid #f06543; background: #fff7e9; font-size: 25px; line-height: 1.7; }
table { width: 100%; border-collapse: collapse; margin-top: 24px; }
th, td { padding: 12px; border: 1px solid #456; }
th { background: #dbeafe; }
.second { padding: 24px; background: #e8f5e9; }
</style></head><body>
<section class="page"><h1>HTML Studio Windows PDF 测试</h1>
<div class="box">中文、背景颜色与边框应完整保留。</div>
<table><tr><th>项目</th><th>结果</th></tr><tr><td>表格渲染</td><td>正常</td></tr></table></section>
<section class="second"><h1>第二页</h1><div class="reserved">预留区域</div>
<p class="crossing">这段中文正文被安排在分页边界附近，Chromium 应当在原生 A4 排版阶段保持段落完整，不得从文字行中间截断。</p>
<table><tr><th>分页测试</th><th>预期结果</th></tr><tr><td>表格行</td><td>不被页面边界截断</td></tr></table></section>
</body></html>`;

app.whenReady().then(async () => {
  await fs.writeFile(logPath, "Electron ready\n", "utf8");
  await fs.rm(outputPath, { force: true });
  const result = await exportHTMLToPDF({
    content: html,
    baseURL: null,
    filePath: outputPath,
    temporaryDirectory: os.tmpdir()
  });
  const data = await fs.readFile(outputPath);
  assert.ok(data.subarray(0, 5).equals(Buffer.from("%PDF-")));
  assert.ok(result.byteLength > 1_000);
  await fs.appendFile(logPath, `PDF created: ${result.byteLength} bytes\n`, "utf8");
  process.stdout.write(`${outputPath}\n`);
  app.quit();
}).catch(async (error) => {
  await fs.writeFile(logPath, `${error.stack || error}\n`, "utf8").catch(() => {});
  process.stderr.write(`${error.stack || error}\n`);
  app.exit(1);
});
