// Run with Playwright installed and its Chromium browser available: npm run test:ui.
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const http = require("node:http");
const path = require("node:path");
const { chromium } = require("playwright");

const root = path.resolve(__dirname, "../src/renderer");
const markdown = Array.from({ length: 31 }, (_, index) => (
  `## 目录 ${index + 1}\n\n${"长文档回归测试。".repeat(60)}\n`
)).join("\n") + "\n| 名称 | 数量 |\n| :--- | ---: |\n| 测试 | 31 |\n";

async function main() {
  const server = http.createServer(async (request, response) => {
    const name = path.basename(new URL(request.url, "http://localhost").pathname) || "index.html";
    if (!["index.html", "styles.css", "guide.js", "converters.js", "renderer.js"].includes(name)) {
      response.writeHead(404).end();
      return;
    }
    response.setHeader("Content-Type", name.endsWith("css") ? "text/css" : name.endsWith("js") ? "text/javascript" : "text/html");
    response.end(await fs.readFile(path.join(root, name)));
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  let browser;
  try {
    browser = await chromium.launch({ channel: process.env.PLAYWRIGHT_BROWSER_CHANNEL || "chromium", headless: true });
    for (const size of [{ width: 1480, height: 900 }, { width: 980, height: 640 }]) {
      const context = await browser.newContext({ viewport: size });
      await context.addInitScript(({ markdown }) => {
        localStorage.setItem("htmlStudioWindowsWorkspaceV3", JSON.stringify({ documents: [
          { id: "old-draft", filePath: "C:\\old.html", html: "<p>未保存的历史草稿</p>", dirty: true },
          { id: "old-saved", filePath: "C:\\saved.html", html: "<p>历史文件</p>", dirty: false }
        ] }));
        window.testSavedHTML = null;
        window.testImportPrompts = 0;
        window.htmlStudioAPI = {
          startupFiles: async () => ({ externalLaunch: true, files: [{ extension: ".md", filePath: "C:\\docs\\测试.md", baseURL: "file:///C:/docs/", content: markdown }] }),
          confirmMarkdownImport: async () => { window.testImportPrompts += 1; return false; },
          onOpenFiles: (callback) => { window.testOpenFiles = callback; },
          onMenuCommand: () => {}, setWindowTitle: async () => {},
          loadHistory: async ({ draftId }) => ({ key: draftId, entries: [] }),
          appendHistory: async ({ entry }) => [entry],
          migrateHistory: async () => ({ key: "saved", entries: [] }),
          saveHTML: async ({ content }) => {
            window.testSavedHTML = content;
            return { filePath: "C:\\docs\\测试.html", baseURL: "file:///C:/docs/" };
          }
        };
      }, { markdown });
      const page = await context.newPage();
      const errors = [];
      page.on("pageerror", (error) => errors.push(error.message));
      await page.goto(`http://127.0.0.1:${server.address().port}/index.html`);
      await page.waitForFunction(() => document.querySelectorAll("#outline button").length === 31);
      await page.waitForFunction(() => window.testImportPrompts === 1);
      assert.equal(await page.locator(".document-tab").count(), 1, "外部文件启动不应恢复历史标签页");
      async function assertLayout(targetPage = page) {
        const layout = await targetPage.evaluate(() => ({
          header: document.querySelector(".app-header").getBoundingClientRect().top,
          footer: document.querySelector(".status-bar").getBoundingClientRect().bottom,
          height: innerHeight, scroll: document.scrollingElement.scrollTop
        }));
        assert.equal(layout.header, 0, "顶部菜单应保持可见");
        assert.equal(layout.footer, layout.height, "状态栏应位于窗口底部");
        assert.equal(layout.scroll, 0, "应用外层不应随预览滚动");
      }
      await assertLayout();
      const last = page.locator("#outline button").last();
      await last.scrollIntoViewIfNeeded();
      await last.click();
      await page.waitForFunction(() => document.querySelector("#design-frame").contentWindow.scrollY > 1000);
      await assertLayout();
      assert.ok(await last.isVisible(), "第 31 项必须能滚动显示并点击");
      await page.locator("#find-button").click();
      await assertLayout();
      await page.locator("#toggle-replace").click();
      await assertLayout();
      await page.locator("#close-find").click();
      await assertLayout();

      const anchor = await page.evaluate(() => {
        const frame = document.querySelector("#design-frame");
        const target = frame.contentDocument.querySelectorAll("h2")[30];
        const range = frame.contentDocument.createRange();
        range.selectNodeContents(target);
        frame.contentWindow.getSelection().removeAllRanges();
        frame.contentWindow.getSelection().addRange(range);
        const x = 100, y = Math.max(12, Math.min(frame.clientHeight - 12, target.getBoundingClientRect().top + 8));
        target.dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true, clientX: x, clientY: y }));
        return { x: frame.getBoundingClientRect().left + x, y: frame.getBoundingClientRect().top + y };
      });
      const menu = await page.locator("#context-menu").boundingBox();
      assert.ok(Math.min(Math.abs(menu.y - anchor.y), Math.abs(menu.y + menu.height - anchor.y)) <= 2, "右键菜单应紧邻点击位置");
      assert.ok(menu.y >= 0 && menu.y + menu.height <= size.height);
      await page.locator("#source-editor").click();
      await page.locator("#save-button").click();
      const saved = await page.evaluate(() => window.testSavedHTML);
      assert.match(saved, /<table>/);
      assert.match(saved, /border-collapse: collapse/);
      assert.match(saved, /text-align: right/);
      const persisted = await page.evaluate(() => JSON.parse(localStorage.getItem("htmlStudioWindowsWorkspaceV3")));
      assert.ok(persisted.documents.some((item) => item.id === "old-draft"), "外部启动必须保留未打开草稿供以后恢复");
      assert.ok(!persisted.documents.some((item) => item.id === "old-saved"));
      await page.locator("#new-button").click();
      await page.waitForFunction(() => document.querySelector("#design-frame").contentDocument?.body?.textContent.trim() === "");
      await assertLayout();
      assert.deepEqual(errors, []);
      await context.close();

      const normalContext = await browser.newContext({ viewport: size });
      await normalContext.addInitScript(() => {
        window.htmlStudioAPI = {
          startupFiles: async () => ({ externalLaunch: false, files: [] }),
          onOpenFiles: () => {}, onMenuCommand: () => {}, setWindowTitle: async () => {},
          loadHistory: async ({ draftId }) => ({ key: draftId, entries: [] }),
          appendHistory: async ({ entry }) => [entry]
        };
      });
      const normalPage = await normalContext.newPage();
      await normalPage.goto(`http://127.0.0.1:${server.address().port}/index.html`);
      await normalPage.waitForFunction(() => document.querySelectorAll(".document-tab").length === 2);
      await assertLayout(normalPage);
      await normalPage.locator("#new-button").click();
      await normalPage.waitForFunction(() => document.querySelector("#design-frame").contentDocument?.body?.textContent.trim() === "");
      await assertLayout(normalPage);
      await normalContext.close();
    }
    console.log("HTML Studio workspace UI regression tests passed (31 headings, two window sizes, file launch, blank page, menus and Markdown save).");
  } finally {
    if (browser) await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
