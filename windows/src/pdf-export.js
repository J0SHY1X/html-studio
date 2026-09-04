const { app, BrowserWindow } = require("electron");
const crypto = require("node:crypto");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");

class PDFRenderError extends Error {
  constructor(message, code = "PDF_RENDER_FAILED") {
    super(message);
    this.name = "PDFRenderError";
    this.code = code;
  }
}

function diagnosticLogPath() {
  const baseDirectory = app && typeof app.getPath === "function" && app.isReady()
    ? app.getPath("userData")
    : path.join(os.tmpdir(), "HTMLStudio");
  return path.join(baseDirectory, "pdf-export.log");
}

async function logPDFEvent(message) {
  const logPath = diagnosticLogPath();
  try {
    await fs.mkdir(path.dirname(logPath), { recursive: true });
    await fs.appendFile(
      logPath,
      `[${new Date().toISOString()}] ${String(message)}\n`,
      "utf8"
    );
  } catch {
    // Diagnostics must never make PDF export or printing fail.
  }
}

async function withStageTimeout(promise, milliseconds, stage) {
  let timer = null;
  try {
    return await Promise.race([
      promise,
      new Promise((_resolve, reject) => {
        timer = setTimeout(() => {
          reject(new PDFRenderError(
            `PDF 渲染在“${stage}”阶段超时，请重试或查看 PDF 导出日志。`,
            "PDF_RENDER_TIMEOUT"
          ));
        }, milliseconds);
      })
    ]);
  } finally {
    if (timer) clearTimeout(timer);
  }
}

function escapeHTMLAttribute(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll('"', "&quot;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function forceEagerResourceLoading(html) {
  return html
    .replace(
      /(\bloading\s*=\s*)(["'])lazy\2/gi,
      (_match, prefix, quote) => `${prefix}${quote}eager${quote}`
    )
    .replace(/(\bloading\s*=\s*)lazy(?=\s|\/?>)/gi, "$1eager");
}

function preparedPDFHTML(content, baseURL) {
  const html = forceEagerResourceLoading(String(content || ""));
  let baseTag = "";
  if (!/<base\b/i.test(html) && typeof baseURL === "string") {
    try {
      const parsed = new URL(baseURL);
      if (["file:", "https:", "http:"].includes(parsed.protocol)) {
        baseTag = `<base href="${escapeHTMLAttribute(parsed.href)}">`;
      }
    } catch {
      // Ignore malformed base URLs; the temporary HTML can still be exported.
    }
  }
  const printStyle = `
<style data-html-studio-pdf>
  html, body { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
  img, svg, table { max-width: 100%; }
  @media print {
    html, body { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
    img, svg, table { max-width: 100%; }
    h1, h2, h3, h4, h5, h6,
    p, li, blockquote, pre, figure, figcaption,
    table, tr, img, svg, hr, details, summary,
    [data-page-break-avoid] {
      break-inside: avoid !important;
      page-break-inside: avoid !important;
      orphans: 2;
      widows: 2;
    }
    thead { display: table-header-group; }
    tfoot { display: table-footer-group; }
    [data-page-break-allow] {
      break-inside: auto !important;
      page-break-inside: auto !important;
    }
  }
</style>`;
  const additions = `${baseTag}${printStyle}`;

  if (/<head\b[^>]*>/i.test(html)) {
    return html.replace(/<head\b[^>]*>/i, (match) => `${match}${additions}`);
  }
  if (/<html\b[^>]*>/i.test(html)) {
    return html.replace(
      /<html\b[^>]*>/i,
      (match) => `${match}<head><meta charset="utf-8">${additions}</head>`
    );
  }
  return `<!doctype html><html><head><meta charset="utf-8">${additions}</head><body>${html}</body></html>`;
}

async function waitForPrintReadiness(webContents) {
  if (!webContents || webContents.isDestroyed()) {
    throw new PDFRenderError("PDF 渲染窗口已意外关闭。", "RENDERER_GONE");
  }

  // The print window intentionally disables JavaScript for untrusted HTML.
  // Calling executeJavaScript in that state can leave its Promise unresolved on
  // some Electron/Chromium versions. loadFile already waits for the document and
  // eager subresources; this deterministic delay lets final layout settle without
  // depending on a page-script callback that may never arrive.
  await new Promise((resolve) => setTimeout(resolve, 350));

  if (webContents.isDestroyed()) {
    throw new PDFRenderError("PDF 渲染进程意外终止。", "RENDERER_GONE");
  }
}

function createPrintWindow(parentWindow = null) {
  const options = {
    show: false,
    width: 794,
    height: 1123,
    backgroundColor: "#ffffff",
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      javascript: false,
      backgroundThrottling: false
    }
  };
  if (parentWindow && !parentWindow.isDestroyed()) options.parent = parentWindow;
  return new BrowserWindow(options);
}

async function loadPrintDocument({
  content,
  baseURL,
  temporaryDirectory,
  printWindow,
  operation
}) {
  const temporaryPath = path.join(
    temporaryDirectory,
    `html-studio-pdf-${crypto.randomUUID()}.html`
  );
  const html = preparedPDFHTML(content, baseURL);
  await fs.writeFile(temporaryPath, html, "utf8");
  await logPDFEvent(`${operation} load start htmlCharacters=${html.length}`);
  await withStageTimeout(
    printWindow.loadFile(temporaryPath),
    15_000,
    "加载页面"
  );
  await waitForPrintReadiness(printWindow.webContents);
  await logPDFEvent(`${operation} load finished`);
  return temporaryPath;
}

async function exportHTMLToPDF({ content, baseURL, filePath, temporaryDirectory }) {
  let temporaryPath = null;
  const partialPath = `${filePath}.html-studio-${crypto.randomUUID()}.tmp`;
  const pdfWindow = createPrintWindow();

  try {
    await logPDFEvent(`export start destination=${filePath}`);
    temporaryPath = await loadPrintDocument({
      content,
      baseURL,
      temporaryDirectory,
      printWindow: pdfWindow,
      operation: "export"
    });
    const buffer = await withStageTimeout(
      pdfWindow.webContents.printToPDF({
        landscape: false,
        displayHeaderFooter: false,
        printBackground: true,
        pageSize: "A4",
        margins: {
          marginType: "custom",
          top: 48,
          bottom: 48,
          left: 48,
          right: 48
        },
        preferCSSPageSize: true
      }),
      45_000,
      "生成 PDF"
    );
    if (!buffer || buffer.byteLength < 5 || buffer.subarray(0, 5).toString() !== "%PDF-") {
      throw new PDFRenderError("Chromium 没有生成有效的 PDF 文件。");
    }
    await fs.writeFile(partialPath, buffer);
    await fs.rm(filePath, { force: true });
    await fs.rename(partialPath, filePath);
    await logPDFEvent(`export finished bytes=${buffer.byteLength}`);
    return { filePath, byteLength: buffer.byteLength };
  } catch (error) {
    await logPDFEvent(`export failed error=${error.message || error}`);
    throw error;
  } finally {
    if (!pdfWindow.isDestroyed()) pdfWindow.destroy();
    if (temporaryPath) await fs.unlink(temporaryPath).catch(() => {});
    await fs.unlink(partialPath).catch(() => {});
  }
}

async function printHTML({
  content,
  baseURL,
  temporaryDirectory,
  parentWindow = null
}) {
  let temporaryPath = null;
  const printWindow = createPrintWindow(parentWindow);

  try {
    await logPDFEvent("print start");
    temporaryPath = await loadPrintDocument({
      content,
      baseURL,
      temporaryDirectory,
      printWindow,
      operation: "print"
    });
    const result = await new Promise((resolve, reject) => {
      printWindow.webContents.print({
        silent: false,
        printBackground: true,
        color: true,
        landscape: false,
        pageSize: "A4",
        margins: {
          marginType: "custom",
          top: 48,
          bottom: 48,
          left: 48,
          right: 48
        }
      }, (success, failureReason) => {
        if (success) {
          resolve({ canceled: false });
          return;
        }
        if (/cancel/i.test(String(failureReason || ""))) {
          resolve({ canceled: true });
          return;
        }
        reject(new PDFRenderError(
          failureReason || "系统打印任务未能启动。",
          "PRINT_FAILED"
        ));
      });
    });
    await logPDFEvent(result.canceled ? "print canceled" : "print submitted");
    return result;
  } catch (error) {
    await logPDFEvent(`print failed error=${error.message || error}`);
    throw error;
  } finally {
    if (!printWindow.isDestroyed()) printWindow.destroy();
    if (temporaryPath) await fs.unlink(temporaryPath).catch(() => {});
  }
}

module.exports = {
  PDFRenderError,
  diagnosticLogPath,
  exportHTMLToPDF,
  printHTML,
  preparedPDFHTML,
  waitForPrintReadiness,
  withStageTimeout
};
