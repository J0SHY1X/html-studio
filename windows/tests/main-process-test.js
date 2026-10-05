const assert = require("node:assert/strict");
const { EventEmitter } = require("node:events");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const vm = require("node:vm");

async function createMain(argumentsList, hasLock = true) {
  const app = new EventEmitter();
  app.requestSingleInstanceLock = () => hasLock;
  app.whenReady = () => Promise.resolve();
  app.addRecentDocument = () => {};
  app.quit = () => { app.didQuit = true; };
  const handlers = new Map();
  const windows = [];
  class BrowserWindow {
    constructor() {
      this.webContents = new EventEmitter();
      this.webContents.send = (...args) => { this.messages.push(args); };
      this.messages = [];
      this.fullScreen = false;
      windows.push(this);
    }
    loadFile() {}
    isDestroyed() { return false; }
    isFullScreen() { return this.fullScreen; }
    setFullScreen(value) { this.fullScreen = value; }
    isMinimized() { return true; }
    restore() { this.restored = true; }
    show() {}
    focus() { this.focused = true; }
    static getAllWindows() { return windows; }
  }
  const electron = { app, BrowserWindow, clipboard: {}, dialog: {}, ipcMain: { handle: (name, fn) => handlers.set(name, fn) }, Menu: { buildFromTemplate: () => [], setApplicationMenu: () => {} } };
  const context = {
    require: (name) => name === "electron" ? electron : name === "./pdf-export" ? {} : name === "./file-launch" ? require("../src/file-launch") : require(name),
    __dirname: path.resolve(__dirname, "../src"),
    process: { argv: ["HTMLStudio.exe", ...argumentsList], platform: "win32" }, console
  };
  vm.runInNewContext(await fs.readFile(path.resolve(__dirname, "../src/main.js"), "utf8"), context);
  await Promise.resolve();
  return { app, handlers, windows };
}

async function main() {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "html-studio-main-test-"));
  try {
    const first = path.join(root, "选择.html"), second = path.join(root, "second.md");
    await fs.writeFile(first, "<h1>指定文件</h1>");
    await fs.writeFile(second, "# Markdown");
    const { app, handlers, windows } = await createMain([first]);
    const startup = await handlers.get("file:startup")();
    assert.equal(startup.externalLaunch, true);
    assert.equal(startup.files.length, 1);
    assert.equal(startup.files[0].content, "<h1>指定文件</h1>");
    const window = windows[0];
    app.emit("second-instance", null, ["HTMLStudio.exe", second], root);
    await new Promise((resolve) => setTimeout(resolve, 30));
    assert.equal(window.messages[0][0], "open-files");
    assert.equal(window.messages[0][1][0].filePath, second);
    assert.equal(windows.length, 1, "打开方式应复用应用实例");
    assert.ok(window.restored && window.focused);
    window.fullScreen = true;
    let prevented = false;
    window.webContents.emit("before-input-event", { preventDefault: () => { prevented = true; } }, { type: "keyDown", key: "Escape" });
    assert.ok(prevented);
    assert.equal(window.fullScreen, false);
    assert.equal((await handlers.get("file:startup")()).externalLaunch, false);
    const secondary = await createMain([], false);
    assert.equal(secondary.windows.length, 0);
    assert.ok(secondary.app.didQuit);
    console.log("HTML Studio main process tests passed (explicit file launch, single instance and Escape).");
  } finally {
    await fs.rm(root, { recursive: true, force: true });
  }
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
