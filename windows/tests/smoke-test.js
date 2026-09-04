const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const requiredFiles = [
  "package.json",
  "src/main.js",
  "src/preload.js",
  "src/pdf-export.js",
  "src/renderer/index.html",
  "src/renderer/styles.css",
  "src/renderer/guide.js",
  "src/renderer/renderer.js",
  "src/renderer/converters.js",
  "Tools/build-windows.js",
  "Tools/build-portable-folder.js",
  "build/icon.ico",
  "build/icon.png"
];

for (const relativePath of requiredFiles) {
  assert.ok(
    fs.existsSync(path.join(root, relativePath)),
    `Missing ${relativePath}`
  );
}

const packageJSON = JSON.parse(
  fs.readFileSync(path.join(root, "package.json"), "utf8")
);
assert.equal(packageJSON.version, "0.3.8");
assert.equal(packageJSON.build.win.target[0].target, "nsis");
assert.match(packageJSON.build.nsis.artifactName, /Setup/);
assert.match(packageJSON.build.portable.artifactName, /Portable/);
assert.match(packageJSON.scripts["portable:folder"], /build-portable-folder/);

for (const relativePath of [
  "src/main.js",
  "src/preload.js",
  "src/pdf-export.js",
  "src/renderer/guide.js",
  "src/renderer/renderer.js",
  "src/renderer/converters.js"
]) {
  const source = fs.readFileSync(path.join(root, relativePath), "utf8");
  new vm.Script(source, { filename: relativePath });
}

const rendererHTML = fs.readFileSync(
  path.join(root, "src/renderer/index.html"),
  "utf8"
);
assert.match(rendererHTML, /sandbox="allow-same-origin"/);
assert.match(rendererHTML, /data-table-action="addRowAfter"/);
assert.match(rendererHTML, /id="document-tab-list"/);
assert.match(rendererHTML, /data-page-action="duplicateCurrent"/);
assert.match(rendererHTML, /data-context-action="paste"/);
assert.match(rendererHTML, /data-context-action="pastePlainText"/);
assert.match(rendererHTML, /id="context-foreground-color"/);
assert.match(rendererHTML, /id="context-highlight-color"/);
assert.match(rendererHTML, /data-context-command="bold"/);
assert.match(rendererHTML, /id="history-dialog"/);
assert.match(rendererHTML, /id="export-docx"/);
assert.match(rendererHTML, /id="export-pdf"/);
assert.match(rendererHTML, /id="print-button"/);
assert.match(rendererHTML, /src="guide\.js"/);
assert.match(rendererHTML, /id="undo-button"/);
assert.match(rendererHTML, /id="redo-button"/);
assert.match(rendererHTML, />↶ 撤销</);
assert.match(rendererHTML, />↷ 重做</);

const rendererJS = fs.readFileSync(
  path.join(root, "src/renderer/renderer.js"),
  "utf8"
);
assert.match(rendererJS, /background: #ffffff/);
assert.match(rendererJS, /function isRangeValid/);
assert.match(rendererJS, /function duplicateCurrentPage/);
assert.match(rendererJS, /function insertBlankPage/);
assert.match(rendererJS, /function captureDesignHTML/);
assert.match(rendererJS, /window\.htmlStudioAPI\.appendHistory/);
assert.match(rendererJS, /workspaceState\.documents/);
assert.match(rendererJS, /function createGuideDocument/);
assert.match(rendererJS, /function showGuide/);
assert.match(rendererJS, /compositionstart/);
assert.match(rendererJS, /compositionupdate/);
assert.match(rendererJS, /compositionend/);
assert.match(rendererJS, /event\.isComposing/);
assert.match(rendererJS, /documentValue\.isComposing/);
assert.match(rendererJS, /function performHistoryCommand/);
assert.match(rendererJS, /function syncSourceEditor/);
assert.match(rendererJS, /workspaceState\.activeEditor/);
assert.match(rendererJS, /frameDocument\.addEventListener\("keydown"/);
assert.match(rendererJS, /async function exportPDF/);
assert.match(rendererJS, /window\.htmlStudioAPI\.exportPDF/);
assert.match(rendererJS, /async function printDocument/);
assert.match(rendererJS, /window\.htmlStudioAPI\.printHTML/);
assert.match(rendererJS, /function designClipboardPayload/);
assert.match(rendererJS, /function sanitizedClipboardHTML/);
assert.match(rendererJS, /function pasteIntoDesign/);
assert.match(rendererJS, /function sourceContextAction/);
assert.match(rendererJS, /function pastePlainTextForActiveSurface/);

const guideJS = fs.readFileSync(
  path.join(root, "src/renderer/guide.js"),
  "utf8"
);
assert.match(guideJS, /HTML Studio 使用说明/);
assert.match(guideJS, /点击标签上的 × 即可关闭/);
assert.match(guideJS, /帮助 → 使用说明/);
assert.match(guideJS, /导出 PDF/);
assert.match(guideJS, /系统打印对话框/);

const preloadJS = fs.readFileSync(
  path.join(root, "src/preload.js"),
  "utf8"
);
assert.match(preloadJS, /readClipboardText/);
assert.match(preloadJS, /readClipboard:/);
assert.match(preloadJS, /writeClipboard:/);
assert.match(preloadJS, /loadHistory/);
assert.match(preloadJS, /migrateHistory/);
assert.match(preloadJS, /file:exportPDF/);
assert.match(preloadJS, /file:print/);

const mainJS = fs.readFileSync(
  path.join(root, "src/main.js"),
  "utf8"
);
assert.match(mainJS, /multiSelections/);
assert.match(mainJS, /history:append/);
assert.match(mainJS, /history:export/);
assert.match(mainJS, /send\("showGuide"\)/);
assert.match(mainJS, /send\("undo"\)/);
assert.match(mainJS, /send\("redo"\)/);
assert.match(mainJS, /file:exportPDF/);
assert.match(mainJS, /file:print/);
assert.match(mainJS, /exportHTMLToPDF/);
assert.match(mainJS, /printHTML/);
assert.match(mainJS, /accelerator: "Ctrl\+P"/);
assert.match(mainJS, /clipboard:read/);
assert.match(mainJS, /clipboard:write/);
assert.match(mainJS, /accelerator: "Ctrl\+Shift\+V"/);

const pdfExportJS = fs.readFileSync(
  path.join(root, "src/pdf-export.js"),
  "utf8"
);
assert.match(pdfExportJS, /printToPDF/);
assert.match(pdfExportJS, /printBackground: true/);
assert.match(pdfExportJS, /pageSize: "A4"/);
assert.match(pdfExportJS, /break-inside: avoid !important/);
assert.match(pdfExportJS, /page-break-inside: avoid !important/);
assert.match(pdfExportJS, /thead \{ display: table-header-group; \}/);
assert.match(pdfExportJS, /withStageTimeout/);
assert.match(pdfExportJS, /pdf-export\.log/);
assert.match(pdfExportJS, /webContents\.print\(/);
assert.doesNotMatch(pdfExportJS, /executeJavaScript\(/);

console.log("HTML Studio Windows smoke tests passed.");
