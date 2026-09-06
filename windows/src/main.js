const {
  app,
  BrowserWindow,
  clipboard,
  dialog,
  ipcMain,
  Menu
} = require("electron");
const crypto = require("node:crypto");
const fs = require("node:fs/promises");
const path = require("node:path");
const { pathToFileURL } = require("node:url");
const { exportHTMLToPDF, printHTML } = require("./pdf-export");
const {
  AlignmentType,
  BorderStyle,
  Document,
  HeadingLevel,
  Packer,
  Paragraph,
  Table,
  TableCell,
  TableRow,
  TextRun,
  WidthType
} = require("docx");

let mainWindow = null;
let printOperationInProgress = false;
const maximumHistoryEntries = 120;

const headingMap = {
  1: HeadingLevel.HEADING_1,
  2: HeadingLevel.HEADING_2,
  3: HeadingLevel.HEADING_3,
  4: HeadingLevel.HEADING_4,
  5: HeadingLevel.HEADING_5,
  6: HeadingLevel.HEADING_6
};

const alignmentMap = {
  left: AlignmentType.LEFT,
  center: AlignmentType.CENTER,
  right: AlignmentType.RIGHT,
  justify: AlignmentType.JUSTIFIED
};

function safeSuggestedName(value, fallback) {
  const name = typeof value === "string" ? path.basename(value) : fallback;
  return name.replace(/[<>:"/\\|?*\u0000-\u001F]/g, "_") || fallback;
}

function baseURLForFile(filePath) {
  const directory = path.dirname(filePath) + path.sep;
  return pathToFileURL(directory).href;
}

function historyDirectory() {
  return path.join(app.getPath("userData"), "History");
}

function historyKey(request = {}) {
  if (typeof request.filePath === "string" && request.filePath) {
    const normalized = path.resolve(request.filePath).toLowerCase();
    return crypto.createHash("sha256").update(normalized).digest("hex");
  }
  const draftId = String(request.draftId || "default")
    .replace(/[^a-zA-Z0-9-]/g, "")
    .slice(0, 80) || "default";
  return `untitled-${draftId.toLowerCase()}`;
}

function historyPath(key) {
  const safeKey = String(key || "default")
    .replace(/[^a-zA-Z0-9-]/g, "")
    .slice(0, 160) || "default";
  return path.join(historyDirectory(), `${safeKey}.json`);
}

async function readHistory(key) {
  try {
    const data = await fs.readFile(historyPath(key), "utf8");
    const entries = JSON.parse(data);
    return Array.isArray(entries) ? entries : [];
  } catch {
    return [];
  }
}

async function writeHistory(key, entries) {
  await fs.mkdir(historyDirectory(), { recursive: true });
  const values = Array.isArray(entries)
    ? entries.slice(-maximumHistoryEntries)
    : [];
  await fs.writeFile(historyPath(key), JSON.stringify(values, null, 2), "utf8");
  return values;
}

function textRunFromModel(run) {
  const options = {
    text: String(run.text || ""),
    bold: Boolean(run.bold),
    italics: Boolean(run.italic),
    strike: Boolean(run.strike)
  };
  if (run.underline) options.underline = {};
  if (run.color && /^[0-9A-Fa-f]{6}$/.test(run.color)) {
    options.color = run.color.toUpperCase();
  }
  if (Number.isFinite(run.size) && run.size >= 8 && run.size <= 144) {
    options.size = Math.round(run.size * 2);
  }
  if (typeof run.font === "string" && run.font.length <= 80) {
    options.font = run.font;
  }
  return new TextRun(options);
}

function paragraphFromModel(block) {
  const runs = Array.isArray(block.runs) && block.runs.length
    ? block.runs.map(textRunFromModel)
    : [new TextRun(String(block.text || ""))];
  const options = {
    children: runs,
    alignment: alignmentMap[block.alignment] || AlignmentType.LEFT,
    spacing: { after: 140, line: 320 }
  };

  if (block.heading && headingMap[block.heading]) {
    options.heading = headingMap[block.heading];
  }
  if (block.list === "bullet") {
    options.bullet = { level: Math.max(0, Math.min(8, block.level || 0)) };
  }
  if (block.list === "number") {
    options.numbering = {
      reference: "html-studio-numbering",
      level: Math.max(0, Math.min(8, block.level || 0))
    };
  }
  if (block.quote) {
    options.indent = { left: 720 };
  }
  return new Paragraph(options);
}

function tableFromModel(block) {
  const rows = Array.isArray(block.rows) ? block.rows : [];
  const border = {
    style: BorderStyle.SINGLE,
    size: 1,
    color: "B8C2CC"
  };
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    borders: {
      top: border,
      bottom: border,
      left: border,
      right: border,
      insideHorizontal: border,
      insideVertical: border
    },
    rows: rows.map((row) => new TableRow({
      children: row.map((cell) => new TableCell({
        children: [
          new Paragraph({
            children: [new TextRun({
              text: String(cell.text || ""),
              bold: Boolean(cell.header)
            })]
          })
        ]
      }))
    }))
  });
}

async function createDOCX(model) {
  const blocks = Array.isArray(model?.blocks) ? model.blocks : [];
  const children = blocks.map((block) => {
    if (block.type === "table") return tableFromModel(block);
    return paragraphFromModel(block);
  });

  const document = new Document({
    numbering: {
      config: [
        {
          reference: "html-studio-numbering",
          levels: Array.from({ length: 9 }, (_, level) => ({
            level,
            format: "decimal",
            text: `%${level + 1}.`,
            alignment: AlignmentType.LEFT,
            style: {
              paragraph: {
                indent: {
                  left: 720 + level * 360,
                  hanging: 360
                }
              }
            }
          }))
        }
      ]
    },
    sections: [
      {
        properties: {},
        children: children.length
          ? children
          : [new Paragraph("HTML Studio")]
      }
    ]
  });
  return Packer.toBuffer(document);
}

function createApplicationMenu() {
  const send = (command) => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send("menu-command", command);
    }
  };

  const template = [
    {
      label: "文件",
      submenu: [
        { label: "新建", accelerator: "Ctrl+N", click: () => send("new") },
        { label: "打开…", accelerator: "Ctrl+O", click: () => send("open") },
        { type: "separator" },
        { label: "保存", accelerator: "Ctrl+S", click: () => send("save") },
        {
          label: "另存为…",
          accelerator: "Ctrl+Shift+S",
          click: () => send("saveAs")
        },
        { type: "separator" },
        { label: "导出 Markdown…", click: () => send("exportMarkdown") },
        { label: "导出 Word (.docx)…", click: () => send("exportDOCX") },
        {
          label: "导出 PDF…",
          accelerator: "Ctrl+Alt+P",
          click: () => send("exportPDF")
        },
        {
          label: "打印…",
          accelerator: "Ctrl+P",
          click: () => send("print")
        },
        { type: "separator" },
        { role: "quit", label: "退出" }
      ]
    },
    {
      label: "编辑",
      submenu: [
        {
          label: "撤销",
          accelerator: "Ctrl+Z",
          click: () => send("undo")
        },
        {
          label: "重做",
          accelerator: "Ctrl+Shift+Z",
          click: () => send("redo")
        },
        { type: "separator" },
        { role: "cut", label: "剪切" },
        { role: "copy", label: "复制" },
        { role: "paste", label: "粘贴" },
        {
          label: "粘贴为纯文本",
          accelerator: "Ctrl+Shift+V",
          click: () => send("pastePlainText")
        },
        { role: "selectAll", label: "全选" },
        { type: "separator" },
        {
          label: "查找…",
          accelerator: "Ctrl+F",
          click: () => send("find")
        },
        {
          label: "查找与替换…",
          accelerator: "Ctrl+H",
          click: () => send("findReplace")
        },
        {
          label: "查找下一个",
          accelerator: "Ctrl+G",
          click: () => send("findNext")
        },
        {
          label: "查找上一个",
          accelerator: "Ctrl+Shift+G",
          click: () => send("findPrevious")
        }
      ]
    },
    {
      label: "历史",
      submenu: [
        {
          label: "查看修改历史…",
          accelerator: "Ctrl+Alt+H",
          click: () => send("showHistory")
        }
      ]
    },
    {
      label: "视图",
      submenu: [
        { role: "reload", label: "重新载入" },
        { role: "togglefullscreen", label: "全屏" }
      ]
    },
    {
      label: "帮助",
      submenu: [
        {
          label: "使用说明",
          accelerator: "F1",
          click: () => send("showGuide")
        }
      ]
    }
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1480,
    height: 900,
    minWidth: 980,
    minHeight: 640,
    backgroundColor: "#111827",
    title: "HTML Studio",
    icon: path.join(__dirname, "..", "build", "icon.ico"),
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webviewTag: false
    }
  });
  mainWindow.loadFile(path.join(__dirname, "renderer", "index.html"));
}

ipcMain.handle("file:open", async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    title: "在标签页中打开网页或 Markdown",
    properties: ["openFile", "multiSelections"],
    filters: [
      { name: "网页与 Markdown", extensions: ["html", "htm", "md", "markdown"] },
      { name: "所有文件", extensions: ["*"] }
    ]
  });
  if (result.canceled || !result.filePaths.length) return [];
  return Promise.all(result.filePaths.map(async (filePath) => {
    const content = await fs.readFile(filePath, "utf8");
    const extension = path.extname(filePath).toLowerCase();
    app.addRecentDocument(filePath);
    return {
      content,
      filePath,
      extension,
      baseURL: baseURLForFile(filePath)
    };
  }));
});

ipcMain.handle("file:saveHTML", async (_event, request) => {
  const content = String(request?.content || "");
  let filePath = typeof request?.filePath === "string" ? request.filePath : null;
  const forceDialog = Boolean(request?.saveAs) || !filePath;

  if (forceDialog) {
    const result = await dialog.showSaveDialog(mainWindow, {
      title: "保存 HTML",
      defaultPath: safeSuggestedName(request?.suggestedName, "未命名.html"),
      filters: [{ name: "HTML 文件", extensions: ["html"] }]
    });
    if (result.canceled || !result.filePath) return null;
    filePath = result.filePath.toLowerCase().endsWith(".html")
      ? result.filePath
      : `${result.filePath}.html`;
  }

  await fs.writeFile(filePath, content, "utf8");
  app.addRecentDocument(filePath);
  return {
    filePath,
    baseURL: baseURLForFile(filePath)
  };
});

ipcMain.handle("file:exportText", async (_event, request) => {
  const requestedExtension = String(request?.extension || "").toLowerCase();
  const extension = ["md", "json"].includes(requestedExtension)
    ? requestedExtension
    : "txt";
  const result = await dialog.showSaveDialog(mainWindow, {
    title: extension === "md"
      ? "导出 Markdown"
      : (extension === "json" ? "导出修改日志" : "导出文本"),
    defaultPath: safeSuggestedName(
      request?.suggestedName,
      `未命名.${extension}`
    ),
    filters: [
      {
        name: extension === "md"
          ? "Markdown 文件"
          : (extension === "json" ? "JSON 文件" : "文本文件"),
        extensions: [extension]
      }
    ]
  });
  if (result.canceled || !result.filePath) return null;
  const filePath = result.filePath.toLowerCase().endsWith(`.${extension}`)
    ? result.filePath
    : `${result.filePath}.${extension}`;
  await fs.writeFile(filePath, String(request?.content || ""), "utf8");
  return { filePath };
});

ipcMain.handle("file:exportDOCX", async (_event, request) => {
  const result = await dialog.showSaveDialog(mainWindow, {
    title: "导出 Word 文档",
    defaultPath: safeSuggestedName(request?.suggestedName, "未命名.docx"),
    filters: [{ name: "Word 文档", extensions: ["docx"] }]
  });
  if (result.canceled || !result.filePath) return null;
  const filePath = result.filePath.toLowerCase().endsWith(".docx")
    ? result.filePath
    : `${result.filePath}.docx`;
  const buffer = await createDOCX(request?.model);
  await fs.writeFile(filePath, buffer);
  return { filePath };
});

ipcMain.handle("file:exportPDF", async (_event, request) => {
  const result = await dialog.showSaveDialog(mainWindow, {
    title: "导出 PDF",
    defaultPath: safeSuggestedName(request?.suggestedName, "未命名.pdf"),
    filters: [{ name: "PDF 文档", extensions: ["pdf"] }]
  });
  if (result.canceled || !result.filePath) return null;

  const filePath = result.filePath.toLowerCase().endsWith(".pdf")
    ? result.filePath
    : `${result.filePath}.pdf`;
  if (printOperationInProgress) {
    throw new Error("已有 PDF 导出或打印任务正在进行，请稍后再试。");
  }
  printOperationInProgress = true;
  try {
    await exportHTMLToPDF({
      content: request?.content,
      baseURL: request?.baseURL,
      filePath,
      temporaryDirectory: app.getPath("temp")
    });
    return { filePath };
  } finally {
    printOperationInProgress = false;
  }
});

ipcMain.handle("file:print", async (_event, request) => {
  if (printOperationInProgress) {
    throw new Error("已有 PDF 导出或打印任务正在进行，请稍后再试。");
  }
  printOperationInProgress = true;
  try {
    return await printHTML({
      content: request?.content,
      baseURL: request?.baseURL,
      temporaryDirectory: app.getPath("temp"),
      parentWindow: mainWindow
    });
  } finally {
    printOperationInProgress = false;
  }
});

ipcMain.handle("clipboard:readText", () => clipboard.readText());

ipcMain.handle("clipboard:writeText", (_event, value) => {
  clipboard.writeText(String(value || ""));
  return true;
});

ipcMain.handle("clipboard:read", () => ({
  text: clipboard.readText(),
  html: clipboard.readHTML()
}));

ipcMain.handle("clipboard:write", (_event, value) => {
  const text = String(value?.text || "");
  const html = typeof value?.html === "string" ? value.html : "";
  clipboard.write(html ? { text, html } : { text });
  return true;
});

ipcMain.handle("history:load", async (_event, request) => {
  const key = historyKey(request);
  return {
    key,
    entries: await readHistory(key)
  };
});

ipcMain.handle("history:append", async (_event, request) => {
  const key = String(request?.key || "");
  const entry = request?.entry;
  if (!key || !entry || typeof entry.html !== "string") {
    throw new Error("修改日志数据无效");
  }
  const values = await readHistory(key);
  const last = values.at(-1);
  if (!(last && last.html === entry.html && last.action === entry.action)) {
    values.push(entry);
  }
  return writeHistory(key, values);
});

ipcMain.handle("history:migrate", async (_event, request) => {
  const oldKey = String(request?.oldKey || "");
  const newKey = historyKey(request);
  if (!oldKey || oldKey === newKey) {
    return { key: newKey, entries: await readHistory(newKey) };
  }
  const combined = [
    ...(await readHistory(newKey)),
    ...(await readHistory(oldKey))
  ].sort((left, right) => String(left.timestamp).localeCompare(String(right.timestamp)));
  const entries = await writeHistory(newKey, combined);
  try {
    await fs.unlink(historyPath(oldKey));
  } catch {
    // The old file may not exist; migration is still complete.
  }
  return { key: newKey, entries };
});

ipcMain.handle("history:export", async (_event, request) => {
  const result = await dialog.showSaveDialog(mainWindow, {
    title: "导出修改日志",
    defaultPath: safeSuggestedName(
      request?.suggestedName,
      "HTML-Studio-修改日志.json"
    ),
    filters: [{ name: "JSON 文件", extensions: ["json"] }]
  });
  if (result.canceled || !result.filePath) return null;
  const filePath = result.filePath.toLowerCase().endsWith(".json")
    ? result.filePath
    : `${result.filePath}.json`;
  await fs.writeFile(
    filePath,
    JSON.stringify(request?.entries || [], null, 2),
    "utf8"
  );
  return { filePath };
});

ipcMain.handle("window:setTitle", (_event, title) => {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.setTitle(String(title || "HTML Studio").slice(0, 240));
  }
});

app.whenReady().then(() => {
  createApplicationMenu();
  createWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
