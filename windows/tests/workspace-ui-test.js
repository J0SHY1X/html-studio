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

async function checkZoomAndComponents(page, assertLayout) {
  const frame = page.frameLocator("#design-frame");
  await frame.locator("body").click();
  const original = await page.locator("#source-editor").inputValue();
  const viewportWidth = await page.evaluate(() => document.querySelector("#design-frame").contentWindow.innerWidth);
  await page.locator("#zoom-in").click();
  await page.locator("#zoom-in").click();
  assert.equal(await page.locator("#zoom-reset").textContent(), "120%");
  const zoomed = await page.evaluate(() => {
    const frame = document.querySelector("#design-frame");
    return { width: frame.contentWindow.innerWidth, scale: frame.getBoundingClientRect().width / frame.clientWidth };
  });
  assert.ok(zoomed.width < viewportWidth && Math.abs(zoomed.scale - 1.2) < 0.01);
  assert.equal(await page.locator("#source-editor").inputValue(), original, "缩放不得改动 HTML");
  assert.ok(await page.locator("#dirty-indicator").evaluate((node) => node.classList.contains("clean")));
  await assertLayout();
  const contextAnchor = await page.evaluate(() => {
    const frame = document.querySelector("#design-frame");
    frame.contentDocument.body.dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true, clientX: 50, clientY: 30 }));
    const rect = frame.getBoundingClientRect();
    return { x: rect.left + 60, y: rect.top + 36 };
  });
  const zoomMenu = await page.locator("#context-menu").boundingBox();
  assert.ok(Math.abs(zoomMenu.x - contextAnchor.x) < 2);
  assert.ok(Math.min(Math.abs(zoomMenu.y - contextAnchor.y), Math.abs(zoomMenu.y + zoomMenu.height - contextAnchor.y)) < 2);
  await page.locator("#zoom-reset").click();
  await page.locator("#zoom-in").click();
  await page.locator("#zoom-in").click();
  const control = await page.locator(".page-zoom").boundingBox();
  const viewport = page.viewportSize();
  assert.ok(control.x + control.width > viewport.width - 20 && control.y + control.height >= viewport.height - 3);
  await page.locator("#zoom-out").click();
  assert.equal(await page.locator("#zoom-reset").textContent(), "110%");
  await page.locator("#zoom-reset").click();
  assert.equal(await page.locator("#zoom-reset").textContent(), "100%");

  await page.locator("#components-button").click();
  await page.locator("#component-insert").click();
  assert.ok(await page.locator("#component-error").isVisible());
  await page.locator("#component-cancel").click();
  assert.equal(await page.locator("#source-editor").inputValue(), original);
  async function insert(kind, values = {}) {
    await page.locator("#components-button").click();
    await page.locator("#component-kind").selectOption(kind);
    for (const name of ["title", "address", "content"]) {
      if (values[name] !== undefined) await page.locator(`#component-${name}`).fill(values[name]);
    }
    await page.locator("#component-insert").click();
    const selectors = {
      link: "a[href^='https://example.com/']", button: "a[role=button]", text: "body", heading: "h2",
      card: "h3", columns: "section,div", quote: "blockquote", divider: "hr", details: "details", input: "input", list: "ul"
    };
    await frame.locator(selectors[kind]).last().waitFor();
    const expected = ({
      link: "参考 &lt;文档&gt;", button: "了解更多", text: "在这里输入正文内容。", heading: "二级标题",
      card: "卡片标题", columns: "左栏内容。", quote: "在这里输入提示或引用内容。", divider: "<hr",
      details: "<details", input: "请输入内容", list: "<li>第一项"
    })[kind];
    await page.waitForFunction((expected) => document.querySelector("#source-editor").value.includes(expected), expected);
  }
  await insert("link", { title: '参考 <文档> & "说明"', address: "https://example.com/?a=1&b=2" });
  assert.equal(await frame.locator('[data-html-studio-component="link"]').textContent(), '参考 <文档> & "说明"');
  await page.locator("#undo-button").click();
  await frame.locator('[data-html-studio-component="link"]').waitFor({ state: "detached" });
  await page.locator("#redo-button").click();
  await frame.locator('[data-html-studio-component="link"]').waitFor();
  await insert("button", { title: "了解更多", address: "#details" });
  assert.equal(await frame.locator('[data-html-studio-component="button"]').getAttribute("role"), "button");
  await page.locator("#image-button").click();
  await page.locator("#component-image-file").setInputFiles({
    name: "本地图片.png", mimeType: "image/png",
    buffer: Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=", "base64")
  });
  await page.locator("#component-image-name").getByText("本地图片.png").waitFor();
  await page.locator("#component-insert").click();
  try {
    await frame.locator('[data-html-studio-component="image"]').waitFor({ state: "attached", timeout: 5000 });
  } catch (error) {
    console.log("Image insertion diagnostic:", await page.evaluate(() => ({
      html: document.querySelector("#design-frame").contentDocument.body.innerHTML,
      error: document.querySelector("#component-error").textContent,
      modal: document.querySelector("#component-dialog").open
    })));
    throw error;
  }
  assert.match(await frame.locator('[data-html-studio-component="image"]').getAttribute("src"), /^data:image\/png;base64,/);
  for (const kind of ["text", "heading", "card", "columns", "quote", "divider", "details", "input", "list"]) {
    await insert(kind);
  }
  assert.equal(await frame.locator('a[role="button"]').textContent(), "了解更多");
  assert.equal(await frame.locator('img').count(), 1, "后续组件插入不应覆盖已有图片");
  assert.equal(await frame.locator('ul li').count(), 3);
  assert.equal(await frame.locator('details summary').textContent(), "点击展开详情");
  await page.locator("#zoom-in").click();
  await page.locator("#save-button").click();
  const saved = await page.evaluate(() => window.testSavedHTML);
  assert.ok(saved.includes("data:image/png;base64,"));
  assert.ok(saved.includes('data-html-studio-component="card"'));
  assert.ok(!saved.includes("page-scale") && !saved.includes("transform: scale"));
  await assertLayout();

  await page.locator('[data-mode="source"]').click();
  assert.ok(await page.locator("#zoom-in").isDisabled());
  const source = '<html><body><p>正文</p></body></html>';
  await page.locator("#source-editor").fill(source);
  await page.locator("#source-editor").evaluate((node) => node.setSelectionRange(node.value.indexOf("</body>"), node.value.indexOf("</body>")));
  await page.locator("#components-button").click();
  await page.locator("#component-kind").selectOption("heading");
  await page.locator("#component-title").fill("源码中插入标题");
  await page.locator("#component-insert").click();
  assert.match(await page.locator("#source-editor").inputValue(), /<p>正文<\/p><h2 [^>]+>源码中插入标题<\/h2><\/body>/);
  await page.locator("#undo-button").click();
  assert.equal(await page.locator("#source-editor").inputValue(), source);
  await page.locator('[data-mode="split"]').click();
  assert.equal(await page.locator("#zoom-reset").textContent(), "110%");
}

async function main() {
  const server = http.createServer(async (request, response) => {
    const name = path.basename(new URL(request.url, "http://localhost").pathname) || "index.html";
    if (!["index.html", "styles.css", "guide.js", "converters.js", "components.js", "renderer.js"].includes(name)) {
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
      await checkZoomAndComponents(page, () => assertLayout());
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
    console.log("HTML Studio workspace UI regression tests passed (31 headings, two window sizes, zoom, 12 components, embedded images, source undo, file launch and save).");
  } finally {
    if (browser) await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
