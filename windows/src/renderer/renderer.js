const starterHTML = `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>未命名页面</title>
  <style>
    body {
      max-width: 820px;
      margin: 56px auto;
      padding: 0 28px;
      color: #172033;
      background: #ffffff;
      font: 17px/1.7 "Segoe UI", "Microsoft YaHei", sans-serif;
    }
    h1 { letter-spacing: -0.025em; }
    .card {
      margin-top: 30px;
      padding: 24px;
      border: 1px solid color-mix(in srgb, currentColor 16%, transparent);
      border-radius: 14px;
      background: #f5f7fb;
    }
  </style>
</head>
<body>
  <h1>欢迎使用 HTML Studio for Windows</h1>
  <p>可以编辑左侧 HTML，也可以直接点击右侧页面进行可视化编辑。</p>
  <div class="card">
    <strong>可以从这里开始：</strong>
    <ul>
      <li>在标签页中同时打开多个 HTML 文件</li>
      <li>像 Word 一样修改字体、段落和表格</li>
      <li>复制当前页面，并在其后增加新页面</li>
      <li>查看修改日志并恢复历史版本</li>
      <li>导出 Markdown、Word 或 PDF 文档</li>
    </ul>
  </div>
</body>
</html>`;

const workspaceStorageKey = "htmlStudioWindowsWorkspaceV3";
const inputActionNames = {
  deleteByCut: "剪切内容",
  insertFromPaste: "粘贴内容",
  insertCompositionText: "中文输入",
  insertFromComposition: "中文输入",
  historyUndo: "撤销",
  historyRedo: "重做",
  deleteContentBackward: "删除内容",
  deleteContentForward: "删除内容",
  deleteByDrag: "移动内容",
  insertFromDrop: "移动内容",
  insertParagraph: "插入段落",
  insertLineBreak: "插入换行"
};
const commandActionNames = {
  bold: "设置粗体",
  italic: "设置斜体",
  underline: "设置下划线",
  strikeThrough: "设置删除线",
  undo: "撤销",
  redo: "重做",
  insertParagraph: "插入段落",
  justifyLeft: "左对齐",
  justifyCenter: "居中",
  justifyRight: "右对齐",
  justifyFull: "两端对齐",
  insertUnorderedList: "设置项目符号列表",
  insertOrderedList: "设置编号列表",
  outdent: "减少缩进",
  indent: "增加缩进",
  createLink: "插入链接",
  unlink: "移除链接",
  insertImage: "插入图片",
  insertHorizontalRule: "插入分隔线",
  removeFormat: "清除格式",
  fontName: "修改字体",
  foreColor: "修改文字颜色",
  hiliteColor: "修改文字底色",
  formatBlock: "修改段落样式"
};

const elements = {
  source: document.querySelector("#source-editor"),
  frame: document.querySelector("#design-frame"),
  workspace: document.querySelector("#workspace"),
  documentName: document.querySelector("#document-name"),
  sidebarName: document.querySelector("#sidebar-name"),
  sidebarPath: document.querySelector("#sidebar-path"),
  outline: document.querySelector("#outline"),
  sourceStats: document.querySelector("#source-stats"),
  lineCount: document.querySelector("#line-count"),
  characterCount: document.querySelector("#character-count"),
  dirtyIndicator: document.querySelector("#dirty-indicator"),
  saveStatus: document.querySelector("#save-status"),
  designStatus: document.querySelector("#design-status"),
  editToggle: document.querySelector("#edit-toggle"),
  toast: document.querySelector("#toast"),
  tableMenu: document.querySelector("#table-menu"),
  pageMenu: document.querySelector("#page-menu"),
  tabList: document.querySelector("#document-tab-list"),
  addTabButton: document.querySelector("#add-tab-button"),
  contextMenu: document.querySelector("#context-menu"),
  historyDialog: document.querySelector("#history-dialog"),
  historyDocumentName: document.querySelector("#history-document-name"),
  historyList: document.querySelector("#history-list"),
  historyAction: document.querySelector("#history-action"),
  historySummary: document.querySelector("#history-summary"),
  historyHTML: document.querySelector("#history-html"),
  restoreHistoryButton: document.querySelector("#restore-history-button"),
  saveButton: document.querySelector("#save-button"),
  undoButton: document.querySelector("#undo-button"),
  redoButton: document.querySelector("#redo-button"),
  findButton: document.querySelector("#find-button"),
  findBar: document.querySelector("#find-replace-bar"),
  findTarget: document.querySelector("#find-target"),
  findInput: document.querySelector("#find-input"),
  replaceInput: document.querySelector("#replace-input"),
  replaceRow: document.querySelector("#replace-row"),
  findPreviousButton: document.querySelector("#find-previous"),
  findNextButton: document.querySelector("#find-next"),
  matchCase: document.querySelector("#match-case"),
  findStatus: document.querySelector("#find-status"),
  toggleReplaceButton: document.querySelector("#toggle-replace"),
  closeFindButton: document.querySelector("#close-find"),
  replaceCurrentButton: document.querySelector("#replace-current"),
  replaceAllButton: document.querySelector("#replace-all"),
  exportMarkdownButton: document.querySelector("#export-markdown"),
  exportDOCXButton: document.querySelector("#export-docx"),
  exportPDFButton: document.querySelector("#export-pdf"),
  printButton: document.querySelector("#print-button"),
  historyButton: document.querySelector("#history-button")
};

const workspaceState = {
  documents: [],
  selectedDocumentId: null,
  lastUserDocumentId: null,
  activeEditor: "design",
  contextTarget: "design",
  contextSourceSelection: { start: 0, end: 0 },
  mode: "split",
  toastTimer: null,
  selectedHistoryId: null
};

const findState = {
  key: "",
  matches: [],
  currentIndex: -1
};

function newId() {
  return crypto.randomUUID();
}

function createDocument(values = {}) {
  const html = typeof values.html === "string" ? values.html : starterHTML;
  const dirty = Boolean(values.dirty);
  return {
    id: typeof values.id === "string" ? values.id : newId(),
    html,
    filePath: typeof values.filePath === "string" ? values.filePath : null,
    importedName: typeof values.importedName === "string" ? values.importedName : null,
    baseURL: typeof values.baseURL === "string" ? values.baseURL : null,
    dirty,
    savedHTML: typeof values.savedHTML === "string"
      ? values.savedHTML
      : (dirty ? "" : html),
    editEnabled: values.editEnabled !== false,
    kind: values.kind === "guide" ? "guide" : "document",
    isComposing: false,
    compositionAction: null,
    savedRange: null,
    activePage: null,
    pendingAction: null,
    sourceRenderTimer: null,
    visualCaptureTimer: null,
    historyTimer: null,
    historyKey: null,
    historyEntries: []
  };
}

function createGuideDocument() {
  return createDocument({
    html: window.HTMLStudioGuideHTML,
    importedName: "使用说明",
    savedHTML: window.HTMLStudioGuideHTML,
    editEnabled: false,
    kind: "guide"
  });
}

function activeDocument() {
  return workspaceState.documents.find(
    (documentValue) => documentValue.id === workspaceState.selectedDocumentId
  ) || workspaceState.documents[0];
}

function isGuide(documentValue = activeDocument()) {
  return documentValue?.kind === "guide";
}

const state = new Proxy({}, {
  get(_target, property) {
    return activeDocument()?.[property];
  },
  set(_target, property, value) {
    const documentValue = activeDocument();
    if (documentValue) documentValue[property] = value;
    return true;
  }
});

function fileName(documentValue = activeDocument()) {
  if (isGuide(documentValue)) return "使用说明";
  if (documentValue?.filePath) {
    return documentValue.filePath.split(/[\\/]/).pop() || "未命名.html";
  }
  return documentValue?.importedName || "未命名.html";
}

function suggestedName(extension) {
  return fileName().replace(/\.[^.]+$/, "") + `.${extension}`;
}

function showToast(message) {
  elements.toast.textContent = message;
  elements.toast.classList.add("visible");
  clearTimeout(workspaceState.toastTimer);
  workspaceState.toastTimer = setTimeout(() => {
    elements.toast.classList.remove("visible");
  }, 2600);
}

function persistWorkspace() {
  const documents = workspaceState.documents.filter((documentValue) => (
    !isGuide(documentValue)
  ));
  const selectedDocumentId = documents.some((documentValue) => (
    documentValue.id === workspaceState.selectedDocumentId
  ))
    ? workspaceState.selectedDocumentId
    : (documents.some((documentValue) => (
      documentValue.id === workspaceState.lastUserDocumentId
    )) ? workspaceState.lastUserDocumentId : documents[0]?.id || null);
  const payload = {
    selectedDocumentId,
    documents: documents.map((documentValue) => ({
      id: documentValue.id,
      html: documentValue.html,
      filePath: documentValue.filePath,
      importedName: documentValue.importedName,
      baseURL: documentValue.baseURL,
      dirty: documentValue.dirty,
      savedHTML: documentValue.savedHTML,
      editEnabled: documentValue.editEnabled
    }))
  };
  try {
    localStorage.setItem(workspaceStorageKey, JSON.stringify(payload));
  } catch {
    showToast("自动草稿空间不足，请及时保存文件。");
  }
}

function updateWindowTitle() {
  const documentValue = activeDocument();
  if (!documentValue) return;
  const title = `${fileName(documentValue)}${documentValue.dirty ? " — 已修改" : ""} · HTML Studio`;
  window.htmlStudioAPI.setWindowTitle(title);
}

function setDirty(value, documentValue = activeDocument()) {
  if (!documentValue) return;
  documentValue.dirty = isGuide(documentValue) ? false : Boolean(value);
  if (documentValue === activeDocument()) {
    elements.dirtyIndicator.classList.toggle("dirty", documentValue.dirty);
    elements.dirtyIndicator.classList.toggle("clean", !documentValue.dirty);
    elements.saveStatus.textContent = isGuide(documentValue)
      ? "内置使用说明"
      : (documentValue.dirty
        ? "有未保存更改"
        : (documentValue.filePath ? "已保存" : "新文档"));
    updateWindowTitle();
  }
  renderTabs();
  persistWorkspace();
}

function updateDocumentInfo() {
  const documentValue = activeDocument();
  if (!documentValue) return;
  const name = fileName(documentValue);
  elements.documentName.textContent = name;
  elements.sidebarName.textContent = name;
  elements.sidebarPath.textContent = isGuide(documentValue)
    ? "内置说明 · 可关闭"
    : (documentValue.filePath || "尚未保存");
  elements.editToggle.checked = !isGuide(documentValue) && documentValue.editEnabled;
}

function updateDocumentControls() {
  const guide = isGuide();
  document.body.classList.toggle("guide-active", guide);
  elements.source.readOnly = guide;
  elements.editToggle.disabled = guide;
  elements.saveButton.disabled = guide;
  elements.undoButton.disabled = guide;
  elements.redoButton.disabled = guide;
  elements.exportMarkdownButton.disabled = guide;
  elements.exportDOCXButton.disabled = guide;
  elements.exportPDFButton.disabled = guide;
  elements.printButton.disabled = guide;
  elements.historyButton.disabled = guide;
  document.querySelectorAll("[data-mode]").forEach((button) => {
    button.disabled = guide;
  });
  applyWorkspaceMode(guide ? "design" : workspaceState.mode);
}

function updateStats() {
  const lines = Math.max(1, state.html.split("\n").length);
  elements.sourceStats.textContent = `${lines} 行`;
  elements.lineCount.textContent = `${lines} 行`;
  elements.characterCount.textContent = `${state.html.length.toLocaleString()} 字符`;
}

function updateOutline() {
  const documentValue = new DOMParser().parseFromString(state.html, "text/html");
  const headings = Array.from(documentValue.querySelectorAll("h1,h2,h3,h4,h5,h6"));
  elements.outline.replaceChildren();
  if (!headings.length) {
    const empty = document.createElement("div");
    empty.className = "empty";
    empty.textContent = "添加 h1–h6 标题后会显示大纲";
    elements.outline.appendChild(empty);
    return;
  }
  headings.forEach((heading, headingIndex) => {
    const button = document.createElement("button");
    const level = Number(heading.tagName[1]);
    button.style.paddingLeft = `${6 + (level - 1) * 8}px`;
    button.innerHTML = `<code>H${level}</code><span></span>`;
    button.querySelector("span").textContent = heading.textContent.trim() || "未命名标题";
    button.addEventListener("click", () => {
      designDocument()?.querySelectorAll("h1,h2,h3,h4,h5,h6")[
        headingIndex
      ]?.scrollIntoView({ behavior: "smooth", block: "center" });
    });
    elements.outline.appendChild(button);
  });
}

function renderTabs() {
  elements.tabList.replaceChildren();
  workspaceState.documents.forEach((documentValue) => {
    const tab = document.createElement("div");
    tab.className = "document-tab";
    tab.classList.toggle(
      "active",
      documentValue.id === workspaceState.selectedDocumentId
    );

    const selectButton = document.createElement("button");
    selectButton.className = "document-tab-select";
    selectButton.title = isGuide(documentValue)
      ? "内置使用说明"
      : (documentValue.filePath || "尚未保存");
    const icon = document.createElement("span");
    icon.textContent = isGuide(documentValue) ? "?" : "</>";
    const label = document.createElement("span");
    label.textContent = fileName(documentValue);
    selectButton.append(icon, label);
    if (documentValue.dirty) {
      const dirty = document.createElement("span");
      dirty.className = "tab-dirty";
      dirty.title = "有未保存更改";
      selectButton.appendChild(dirty);
    }
    selectButton.addEventListener("click", () => selectDocument(documentValue));

    const closeButton = document.createElement("button");
    closeButton.className = "document-tab-close";
    closeButton.textContent = "×";
    closeButton.title = `关闭 ${fileName(documentValue)}`;
    closeButton.addEventListener("click", (event) => {
      event.stopPropagation();
      closeDocument(documentValue);
    });

    tab.append(selectButton, closeButton);
    elements.tabList.appendChild(tab);
  });
}

function applyHTML(value, options = {}) {
  const documentValue = activeDocument();
  if (!documentValue) return;
  documentValue.html = String(value);
  elements.source.value = documentValue.html;
  updateStats();
  updateOutline();
  if (options.render !== false) schedulePreviewRender();
  if (options.dirty !== undefined) setDirty(options.dirty, documentValue);
  else persistWorkspace();
}

function refreshActiveDocument() {
  const documentValue = activeDocument();
  if (!documentValue) return;
  elements.source.value = documentValue.html;
  updateDocumentInfo();
  updateDocumentControls();
  updateStats();
  updateOutline();
  setDirty(documentValue.dirty, documentValue);
  renderPreview();
  clearFindState();
  if (!elements.findBar.hidden) {
    updateFindControls();
    if (workspaceState.activeEditor === "source" && elements.findInput.value) {
      performFind(false, true);
    } else {
      setFindStatus();
    }
  }
}

function selectDocument(documentValue) {
  if (!documentValue || documentValue.id === workspaceState.selectedDocumentId) return;
  saveSelection();
  workspaceState.selectedDocumentId = documentValue.id;
  if (!isGuide(documentValue)) workspaceState.lastUserDocumentId = documentValue.id;
  workspaceState.selectedHistoryId = null;
  refreshActiveDocument();
  persistWorkspace();
}

function closeDocument(documentValue) {
  if (!documentValue) return;
  if (documentValue.dirty && !window.confirm(
    `“${fileName(documentValue)}”有未保存更改。\n\n确定要不保存并关闭此标签页吗？`
  )) {
    return;
  }
  const index = workspaceState.documents.indexOf(documentValue);
  workspaceState.documents.splice(index, 1);
  if (workspaceState.lastUserDocumentId === documentValue.id) {
    workspaceState.lastUserDocumentId =
      workspaceState.documents.find((item) => !isGuide(item))?.id || null;
  }
  if (!workspaceState.documents.length) {
    const replacement = createDocument();
    workspaceState.documents.push(replacement);
    workspaceState.selectedDocumentId = replacement.id;
    workspaceState.lastUserDocumentId = replacement.id;
    initializeHistory(replacement, "创建文档", "文件");
  } else if (workspaceState.selectedDocumentId === documentValue.id) {
    const replacement = workspaceState.documents.find((item) => (
      item.id === workspaceState.lastUserDocumentId
    )) || workspaceState.documents[Math.min(index, workspaceState.documents.length - 1)];
    workspaceState.selectedDocumentId = replacement.id;
    if (!isGuide(replacement)) workspaceState.lastUserDocumentId = replacement.id;
  }
  refreshActiveDocument();
  persistWorkspace();
}

function injectEditorSupport(html) {
  const documentValue = new DOMParser().parseFromString(html, "text/html");
  if (state.baseURL) {
    const base = documentValue.createElement("base");
    base.href = state.baseURL;
    base.dataset.htmlStudioUi = "base";
    documentValue.head.prepend(base);
  }
  const style = documentValue.createElement("style");
  style.dataset.htmlStudioUi = "editing-style";
  style.textContent = `
    body[data-html-studio-editing="true"] { min-height: 100vh !important; cursor: text; }
    body[data-html-studio-editing="true"]:focus { outline: none; }
    body[data-html-studio-editing="true"] *:hover { outline: 1px dashed rgba(59,130,246,.3); outline-offset: 2px; }
    body[data-html-studio-editing="true"] [data-html-studio-active-page] {
      outline: 2px dashed rgba(37,99,235,.55) !important;
      outline-offset: 4px !important;
    }
    body[data-html-studio-editing="true"] td,
    body[data-html-studio-editing="true"] th { min-width: 36px; min-height: 22px; }
  `;
  documentValue.head.appendChild(style);
  return `<!doctype html>\n${documentValue.documentElement.outerHTML}`;
}

function schedulePreviewRender() {
  const documentValue = activeDocument();
  if (!documentValue || documentValue.isComposing) return;
  clearTimeout(documentValue.sourceRenderTimer);
  documentValue.sourceRenderTimer = setTimeout(() => {
    if (documentValue === activeDocument()) renderPreview();
  }, 180);
}

function renderPreview() {
  if (state.isComposing) return;
  state.savedRange = null;
  state.activePage = null;
  elements.designStatus.textContent = "正在重新渲染…";
  elements.frame.srcdoc = injectEditorSupport(state.html);
}

function designDocument() {
  try {
    return elements.frame.contentDocument;
  } catch {
    return null;
  }
}

function designWindow() {
  try {
    return elements.frame.contentWindow;
  } catch {
    return null;
  }
}

function setDesignEditable() {
  const frameDocument = designDocument();
  if (!frameDocument?.body) return;
  const editable = Boolean(state.editEnabled && !isGuide());
  const editableValue = editable ? "true" : "false";
  const changed = frameDocument.body.contentEditable !== editableValue;
  if (changed) frameDocument.body.contentEditable = editableValue;
  frameDocument.body.spellcheck = editable;
  frameDocument.body.dataset.htmlStudioEditing = editableValue;
  elements.designStatus.textContent = isGuide()
    ? "使用说明（只读）"
    : (editable
      ? "可直接编辑；右键支持剪贴板、文字颜色、段落和页面操作"
      : "只读预览（页面脚本为安全起见保持禁用）");
  if (editable && changed && !state.isComposing) repairSelection();
}

function isRangeValid(range) {
  const body = designDocument()?.body;
  if (!range || !body) return false;
  try {
    return Boolean(
      range.startContainer?.isConnected &&
      range.endContainer?.isConnected &&
      body.contains(range.startContainer) &&
      body.contains(range.endContainer)
    );
  } catch {
    return false;
  }
}

function placeCaretAtEnd(target = null) {
  const frameDocument = designDocument();
  const selection = designWindow()?.getSelection();
  if (!frameDocument?.body || !selection) return null;
  const root = target?.isConnected ? target : frameDocument.body;
  const range = frameDocument.createRange();
  range.selectNodeContents(root);
  range.collapse(false);
  selection.removeAllRanges();
  selection.addRange(range);
  state.savedRange = range.cloneRange();
  return range;
}

function saveSelection() {
  if (state.isComposing) return;
  const selection = designWindow()?.getSelection();
  if (!selection || selection.rangeCount === 0) return;
  const range = selection.getRangeAt(0);
  if (!isRangeValid(range)) return;
  state.savedRange = range.cloneRange();
  markActivePage(range.startContainer);
}

function restoreSelection() {
  if (state.isComposing) return false;
  const selection = designWindow()?.getSelection();
  if (!selection) return false;
  if (!isRangeValid(state.savedRange)) {
    state.savedRange = null;
    placeCaretAtEnd(state.activePage);
    return false;
  }
  try {
    selection.removeAllRanges();
    selection.addRange(state.savedRange);
    return true;
  } catch {
    state.savedRange = null;
    placeCaretAtEnd(state.activePage);
    return false;
  }
}

function repairSelection() {
  if (state.isComposing) return;
  const selection = designWindow()?.getSelection();
  if (selection?.rangeCount && isRangeValid(selection.getRangeAt(0))) {
    state.savedRange = selection.getRangeAt(0).cloneRange();
    return;
  }
  state.savedRange = null;
  placeCaretAtEnd(state.activePage);
}

function refocusDesign() {
  const body = designDocument()?.body;
  if (!state.editEnabled || state.isComposing || isGuide() || !body) return;
  if (body.contentEditable !== "true") body.contentEditable = "true";
  body.focus({ preventScroll: true });
  restoreSelection();
}

function changeSummary(previousCount, newCount) {
  const difference = newCount - previousCount;
  if (!difference) return `字符数未变化；当前 ${newCount} 个字符`;
  return `${difference > 0 ? "增加" : "减少"} ${Math.abs(difference)} 个字符；当前 ${newCount} 个字符`;
}

async function appendHistory(documentValue, action, source, summary) {
  if (!documentValue || isGuide(documentValue)) return;
  if (!documentValue.historyKey) {
    await initializeHistory(documentValue);
  }
  const entry = {
    id: newId(),
    timestamp: new Date().toISOString(),
    source,
    action,
    summary,
    filePath: documentValue.filePath,
    html: documentValue.html
  };
  documentValue.historyEntries.push(entry);
  documentValue.historyEntries = documentValue.historyEntries.slice(-120);
  try {
    documentValue.historyEntries = await window.htmlStudioAPI.appendHistory({
      key: documentValue.historyKey,
      entry
    });
  } catch {
    showToast("修改已完成，但日志暂时无法写入磁盘。");
  }
  if (elements.historyDialog.open && documentValue === activeDocument()) {
    renderHistory();
  }
}

function scheduleHistory(documentValue, action, source, summary) {
  clearTimeout(documentValue.historyTimer);
  documentValue.historyTimer = setTimeout(() => {
    appendHistory(documentValue, action, source, summary);
  }, 650);
}

async function initializeHistory(
  documentValue,
  initialAction = null,
  initialSource = "文件"
) {
  if (!documentValue || isGuide(documentValue)) return;
  try {
    const result = await window.htmlStudioAPI.loadHistory({
      filePath: documentValue.filePath,
      draftId: documentValue.id
    });
    documentValue.historyKey = result.key;
    documentValue.historyEntries = Array.isArray(result.entries)
      ? result.entries
      : [];
    if (initialAction || !documentValue.historyEntries.length) {
      await appendHistory(
        documentValue,
        initialAction || "创建文档",
        initialSource,
        `${documentValue.html.length} 个字符`
      );
    }
  } catch {
    documentValue.historyKey = `untitled-${documentValue.id}`;
  }
}

function captureDesignHTML(action = "编辑可视化页面") {
  const documentValue = activeDocument();
  const frameDocument = designDocument();
  if (!documentValue || isGuide(documentValue) || documentValue.isComposing ||
      !frameDocument?.documentElement) return;
  const previousCount = documentValue.html.length;
  saveSelection();
  const clone = frameDocument.documentElement.cloneNode(true);
  clone.querySelectorAll("[data-html-studio-ui]").forEach((node) => node.remove());
  clone.querySelectorAll("[data-html-studio-active-page]").forEach((node) => {
    node.removeAttribute("data-html-studio-active-page");
  });
  const body = clone.querySelector("body");
  if (body) {
    body.removeAttribute("contenteditable");
    body.removeAttribute("spellcheck");
    body.removeAttribute("data-html-studio-editing");
  }
  documentValue.html = `<!DOCTYPE html>\n${clone.outerHTML}`;
  elements.source.value = documentValue.html;
  updateStats();
  updateOutline();
  setDirty(true, documentValue);
  scheduleHistory(
    documentValue,
    action,
    "页面",
    changeSummary(previousCount, documentValue.html.length)
  );
}

function scheduleDesignCapture(action = "编辑可视化页面") {
  const documentValue = activeDocument();
  if (!documentValue || documentValue.isComposing || isGuide(documentValue)) return;
  clearTimeout(documentValue.visualCaptureTimer);
  documentValue.visualCaptureTimer = setTimeout(() => {
    if (documentValue === activeDocument()) captureDesignHTML(action);
  }, 100);
}

function prepareCommand() {
  if (isGuide()) {
    showToast("使用说明为只读页面；关闭该标签后即可编辑文档。");
    return null;
  }
  if (state.isComposing) {
    showToast("请先确认当前输入法候选文字。");
    return null;
  }
  if (!state.editEnabled) {
    showToast("请先启用“直接编辑”。");
    return null;
  }
  const frameDocument = designDocument();
  if (!frameDocument?.body) return null;
  frameDocument.body.focus({ preventScroll: true });
  restoreSelection();
  frameDocument.execCommand("styleWithCSS", false, true);
  return frameDocument;
}

function executeCommand(command, value = null, action = null) {
  const frameDocument = prepareCommand();
  if (!frameDocument) return;
  frameDocument.execCommand(command, false, value);
  repairSelection();
  scheduleDesignCapture(action || commandActionNames[command] || "执行编辑命令");
}

function syncSourceEditor(action = "编辑 HTML 源码") {
  const documentValue = activeDocument();
  if (!documentValue || isGuide(documentValue) ||
      elements.source.value === documentValue.html) {
    return;
  }
  const previousCount = documentValue.html.length;
  documentValue.html = elements.source.value;
  updateStats();
  updateOutline();
  setDirty(true, documentValue);
  scheduleHistory(
    documentValue,
    action,
    "源码",
    changeSummary(previousCount, documentValue.html.length)
  );
  schedulePreviewRender();
}

function performHistoryCommand(command) {
  if (isGuide()) {
    showToast("使用说明为只读页面。");
    return;
  }
  if (workspaceState.activeEditor === "source") {
    elements.source.focus({ preventScroll: true });
    document.execCommand(command);
    queueMicrotask(() => {
      syncSourceEditor(command === "undo" ? "撤销源码编辑" : "重做源码编辑");
    });
    return;
  }
  executeCommand(command);
}

function setFontSize(pixelSize) {
  const frameDocument = prepareCommand();
  if (!frameDocument) return;
  frameDocument.execCommand("fontSize", false, "7");
  frameDocument.querySelectorAll('font[size="7"]').forEach((font) => {
    font.removeAttribute("size");
    font.style.fontSize = `${pixelSize}px`;
  });
  repairSelection();
  scheduleDesignCapture("修改字号");
}

function insertTable(rows, columns) {
  const frameDocument = prepareCommand();
  if (!frameDocument) return;
  const rowCount = Math.max(1, Math.min(20, rows));
  const columnCount = Math.max(1, Math.min(12, columns));
  const table = frameDocument.createElement("table");
  table.style.cssText = "border-collapse:collapse;width:100%;margin:1em 0";
  const tbody = frameDocument.createElement("tbody");
  for (let rowIndex = 0; rowIndex < rowCount; rowIndex += 1) {
    const row = frameDocument.createElement("tr");
    for (let columnIndex = 0; columnIndex < columnCount; columnIndex += 1) {
      const cell = frameDocument.createElement("td");
      cell.style.cssText = "border:1px solid #cbd5e1;padding:8px;min-width:48px";
      cell.innerHTML = "<br>";
      row.appendChild(cell);
    }
    tbody.appendChild(row);
  }
  table.appendChild(tbody);
  const trailingParagraph = frameDocument.createElement("p");
  trailingParagraph.innerHTML = "<br>";

  restoreSelection();
  const selection = designWindow()?.getSelection();
  let node = selection?.anchorNode || frameDocument.body;
  if (node.nodeType === 3) node = node.parentElement;
  const anchor = node.closest?.(
    "table,p,h1,h2,h3,h4,h5,h6,blockquote,pre,ul,ol,section,article"
  );
  if (!anchor || anchor === frameDocument.body) {
    frameDocument.body.append(table, trailingParagraph);
  } else {
    anchor.after(table, trailingParagraph);
  }

  const range = frameDocument.createRange();
  range.selectNodeContents(table.querySelector("td"));
  range.collapse(true);
  selection.removeAllRanges();
  selection.addRange(range);
  state.savedRange = range.cloneRange();
  scheduleDesignCapture(`插入 ${rowCount} × ${columnCount} 表格`);
}

function currentTableCell() {
  restoreSelection();
  const selection = designWindow()?.getSelection();
  let node = selection?.anchorNode;
  if (node?.nodeType === 3) node = node.parentElement;
  return node?.closest?.("td,th") || null;
}

function emptyCellLike(cell) {
  const replacement = designDocument().createElement(cell.tagName.toLowerCase());
  Array.from(cell.attributes).forEach((attribute) => {
    replacement.setAttribute(attribute.name, attribute.value);
  });
  replacement.innerHTML = "<br>";
  return replacement;
}

function tableAction(action) {
  const frameDocument = prepareCommand();
  if (!frameDocument) return;
  const cell = currentTableCell();
  const row = cell?.closest("tr");
  const table = cell?.closest("table");
  if (!cell || !row || !table) {
    showToast("请先把光标放入表格单元格。");
    return;
  }

  const names = {
    addRowBefore: "在上方添加表格行",
    addRowAfter: "在下方添加表格行",
    addColumnBefore: "在左侧添加表格列",
    addColumnAfter: "在右侧添加表格列",
    deleteRow: "删除表格行",
    deleteColumn: "删除表格列",
    toggleHeader: "切换表头",
    deleteTable: "删除表格"
  };
  const cellIndex = Array.from(row.cells).indexOf(cell);
  if (action === "addRowBefore" || action === "addRowAfter") {
    const newRow = frameDocument.createElement("tr");
    Array.from(row.cells).forEach((sourceCell) => {
      newRow.appendChild(emptyCellLike(sourceCell));
    });
    row.parentNode.insertBefore(
      newRow,
      action === "addRowBefore" ? row : row.nextSibling
    );
  } else if (action === "addColumnBefore" || action === "addColumnAfter") {
    const offset = action === "addColumnAfter" ? 1 : 0;
    Array.from(table.rows).forEach((targetRow) => {
      const reference = targetRow.cells[Math.min(cellIndex, targetRow.cells.length - 1)];
      const newCell = emptyCellLike(reference || cell);
      const insertionIndex = Math.min(cellIndex + offset, targetRow.cells.length);
      if (insertionIndex >= targetRow.cells.length) targetRow.appendChild(newCell);
      else targetRow.insertBefore(newCell, targetRow.cells[insertionIndex]);
    });
  } else if (action === "deleteRow") {
    row.remove();
    if (!table.rows.length) table.remove();
  } else if (action === "deleteColumn") {
    Array.from(table.rows).forEach((targetRow) => {
      targetRow.cells[cellIndex]?.remove();
    });
    if (!table.rows.length || !table.rows[0].cells.length) table.remove();
  } else if (action === "toggleHeader") {
    const firstRow = table.rows[0];
    const makeHeader = Array.from(firstRow.cells).some((item) => item.tagName !== "TH");
    Array.from(firstRow.cells).forEach((oldCell) => {
      const newCell = frameDocument.createElement(makeHeader ? "th" : "td");
      Array.from(oldCell.attributes).forEach((attribute) => {
        newCell.setAttribute(attribute.name, attribute.value);
      });
      newCell.innerHTML = oldCell.innerHTML;
      oldCell.replaceWith(newCell);
    });
  } else if (action === "deleteTable") {
    table.remove();
  }
  scheduleDesignCapture(names[action] || "修改表格");
}

function pageElements() {
  const frameDocument = designDocument();
  if (!frameDocument) return [];
  const selector = "[data-slide], [data-page], [data-page-number], .slide, .page, .html-studio-page";
  return Array.from(frameDocument.querySelectorAll(selector)).filter((page) => {
    return !page.parentElement?.closest?.(selector);
  });
}

function ensurePageStructure() {
  const existing = pageElements();
  if (existing.length) return existing;
  const frameDocument = designDocument();
  const section = frameDocument.createElement("section");
  section.className = "html-studio-page";
  section.dataset.page = "1";
  Array.from(frameDocument.body.childNodes)
    .filter((node) => !(node.nodeType === 1 && ["SCRIPT", "STYLE"].includes(node.tagName)))
    .forEach((node) => section.appendChild(node));
  frameDocument.body.prepend(section);
  return [section];
}

function markActivePage(node) {
  const frameDocument = designDocument();
  let element = node;
  if (element?.nodeType === 3) element = element.parentElement;
  const selector = "[data-slide], [data-page], [data-page-number], .slide, .page, .html-studio-page";
  const pages = pageElements();
  const page = element?.closest?.(selector) || state.activePage || pages[0];
  if (!page || !page.isConnected) return null;
  frameDocument.querySelectorAll("[data-html-studio-active-page]").forEach((item) => {
    item.removeAttribute("data-html-studio-active-page");
  });
  page.setAttribute("data-html-studio-active-page", "true");
  state.activePage = page;
  return page;
}

function currentPage() {
  let pages = pageElements();
  if (!pages.length) pages = ensurePageStructure();
  const selection = designWindow()?.getSelection();
  const fromSelection = selection?.rangeCount
    ? markActivePage(selection.getRangeAt(0).startContainer)
    : null;
  return fromSelection || markActivePage(state.activePage) || pages[0] || null;
}

function sanitizeClonedIDs(clone) {
  const suffix = `-copy-${Date.now().toString(36)}`;
  [clone, ...clone.querySelectorAll("[id]")].forEach((node) => {
    if (node.id) node.id += suffix;
  });
  clone.querySelectorAll("[data-html-studio-active-page]").forEach((node) => {
    node.removeAttribute("data-html-studio-active-page");
  });
}

function renumberPages() {
  const frameDocument = designDocument();
  const pages = pageElements();
  pages.forEach((page, index) => {
    const number = index + 1;
    if (page.hasAttribute("data-slide")) page.dataset.slide = String(number);
    if (page.hasAttribute("data-page-number")) page.dataset.pageNumber = String(number);
    if (page.hasAttribute("data-page") &&
        /^\d*$/.test(page.getAttribute("data-page") || "")) {
      page.dataset.page = String(number);
    }
    if (/^(slide|page)-\d+(?:-copy-[a-z0-9]+)?$/i.test(page.id)) {
      page.id = `slide-${number}`;
    }
    const label = page.querySelector(
      ".slide-no, .page-no, .page-number, [data-page-label]"
    );
    if (label && /^第\s*\d+\s*页$/.test(label.textContent.trim())) {
      label.textContent = `第${number}页`;
    }
  });

  const toc = frameDocument.querySelector("#toc");
  if (toc && pages.every((page) => page.id)) {
    toc.replaceChildren(...pages.map((page, index) => {
      const link = frameDocument.createElement("a");
      const title = page.querySelector("h1,h2,h3")?.textContent?.trim() || "未命名页面";
      link.href = `#${page.id}`;
      link.textContent = `${index + 1}｜${title}`;
      return link;
    }));
  }
  return pages;
}

function duplicateCurrentPage() {
  if (!state.editEnabled) return;
  const page = currentPage();
  if (!page) {
    showToast("未找到可复制的页面。");
    return;
  }
  const clone = page.cloneNode(true);
  sanitizeClonedIDs(clone);
  page.after(clone);
  const pages = renumberPages();
  const number = pages.indexOf(clone) + 1;
  markActivePage(clone);
  clone.scrollIntoView({ behavior: "smooth", block: "start" });
  placeCaretAtEnd(clone);
  captureDesignHTML(`复制页面并新增第 ${number} 页`);
  showToast(`已复制为第 ${number} 页，可直接修改内容。`);
}

function insertBlankPage() {
  if (!state.editEnabled) return;
  const page = currentPage();
  if (!page) return;
  const frameDocument = designDocument();
  const blank = frameDocument.createElement(page.tagName.toLowerCase());
  Array.from(page.attributes).forEach((attribute) => {
    if (["id", "data-html-studio-active-page"].includes(attribute.name)) return;
    blank.setAttribute(attribute.name, attribute.value);
  });
  if (page.matches(".slide, [data-slide]")) {
    blank.innerHTML = `
      <div class="slide-head">
        <span class="slide-no">第0页</span>
        <span class="time"></span>
      </div>
      <h2>新页面</h2>
      <div class="script"><p><br></p></div>
    `;
  } else {
    blank.innerHTML = "<h2>新页面</h2><p><br></p>";
  }
  page.after(blank);
  const pages = renumberPages();
  const number = pages.indexOf(blank) + 1;
  markActivePage(blank);
  blank.scrollIntoView({ behavior: "smooth", block: "start" });
  const editableBlock = blank.querySelector("h1,h2,h3,p") || blank;
  const range = frameDocument.createRange();
  range.selectNodeContents(editableBlock);
  const selection = designWindow().getSelection();
  selection.removeAllRanges();
  selection.addRange(range);
  state.savedRange = range.cloneRange();
  captureDesignHTML(`新增空白第 ${number} 页`);
  showToast(`已新增第 ${number} 页。`);
}

function pageAction(action) {
  if (action === "duplicateCurrent") duplicateCurrentPage();
  else if (action === "insertBlankAfter") insertBlankPage();
}

function showContextMenu(x, y, target = "design") {
  workspaceState.contextTarget = target;
  elements.contextMenu.querySelectorAll('[data-context-scope="design"]').forEach((item) => {
    item.hidden = target !== "design";
  });
  elements.contextMenu.hidden = false;
  elements.contextMenu.scrollTop = 0;
  const bounds = elements.contextMenu.getBoundingClientRect();
  elements.contextMenu.style.left = `${Math.max(6, Math.min(x, innerWidth - bounds.width - 6))}px`;
  elements.contextMenu.style.top = `${Math.max(6, Math.min(y, innerHeight - bounds.height - 6))}px`;
}

function hideContextMenu() {
  elements.contextMenu.hidden = true;
}

function designClipboardPayload() {
  const selection = designWindow()?.getSelection();
  const frameDocument = designDocument();
  if (!selection || !frameDocument || selection.rangeCount === 0) {
    return { text: "", html: "" };
  }
  const range = selection.getRangeAt(0);
  const container = frameDocument.createElement("div");
  container.appendChild(range.cloneContents());
  return { text: selection.toString(), html: container.innerHTML };
}

function sanitizedClipboardHTML(value) {
  const parsed = new DOMParser().parseFromString(String(value || ""), "text/html");
  parsed.querySelectorAll("script,iframe,object,embed,meta,base").forEach((node) => node.remove());
  parsed.querySelectorAll("*").forEach((node) => {
    Array.from(node.attributes).forEach((attribute) => {
      const name = attribute.name.toLowerCase();
      const content = attribute.value.trim().toLowerCase();
      if (name.startsWith("on") || name === "srcdoc" ||
          (["href", "src", "xlink:href"].includes(name) && content.startsWith("javascript:"))) {
        node.removeAttribute(attribute.name);
      }
    });
  });
  return parsed.body.innerHTML;
}

async function pasteIntoDesign(plainTextOnly = false) {
  const frameDocument = prepareCommand();
  if (!frameDocument) return;
  const payload = await window.htmlStudioAPI.readClipboard();
  refocusDesign();
  const safeHTML = plainTextOnly ? "" : sanitizedClipboardHTML(payload?.html);
  if (safeHTML) frameDocument.execCommand("insertHTML", false, safeHTML);
  else frameDocument.execCommand("insertText", false, String(payload?.text || ""));
  repairSelection();
  captureDesignHTML(plainTextOnly ? "粘贴为纯文本" : "粘贴内容");
}

function restoreContextSourceSelection() {
  elements.source.focus({ preventScroll: true });
  const maximum = elements.source.value.length;
  const start = Math.max(0, Math.min(workspaceState.contextSourceSelection.start, maximum));
  const end = Math.max(start, Math.min(workspaceState.contextSourceSelection.end, maximum));
  elements.source.setSelectionRange(start, end);
  return { start, end };
}

function replaceSourceSelection(text, action) {
  const selection = restoreContextSourceSelection();
  const value = String(text || "");
  const inserted = document.execCommand("insertText", false, value);
  if (!inserted) {
    elements.source.setRangeText(value, selection.start, selection.end, "end");
  }
  workspaceState.contextSourceSelection = {
    start: elements.source.selectionStart,
    end: elements.source.selectionEnd
  };
  syncSourceEditor(action);
}

async function sourceContextAction(action) {
  const selection = restoreContextSourceSelection();
  const selectedText = elements.source.value.slice(selection.start, selection.end);
  if (isGuide() && !["copy", "selectAll"].includes(action)) {
    showToast("使用说明为只读页面。");
    return;
  }
  if (action === "copy" || action === "cut") {
    await window.htmlStudioAPI.writeClipboard({ text: selectedText, html: "" });
    if (action === "cut") {
      replaceSourceSelection("", "剪切 HTML 源码");
    }
  } else if (action === "paste" || action === "pastePlainText") {
    const payload = await window.htmlStudioAPI.readClipboard();
    replaceSourceSelection(payload?.text, action === "pastePlainText" ? "粘贴纯文本源码" : "粘贴 HTML 源码");
  } else if (action === "delete") {
    replaceSourceSelection("", "删除 HTML 源码");
  } else if (action === "selectAll") {
    elements.source.select();
    workspaceState.contextSourceSelection = { start: 0, end: elements.source.value.length };
  } else if (action === "undo" || action === "redo") {
    document.execCommand(action);
    queueMicrotask(() => syncSourceEditor(action === "undo" ? "撤销源码编辑" : "重做源码编辑"));
  }
}

async function contextAction(action) {
  hideContextMenu();
  if (action === "find" || action === "findReplace") {
    activateEditorSurface(workspaceState.contextTarget);
    openFindBar(action === "findReplace");
    return;
  }
  if (workspaceState.contextTarget === "source") {
    await sourceContextAction(action);
    return;
  }
  if (["duplicateCurrent", "insertBlankAfter"].includes(action)) {
    pageAction(action);
    return;
  }
  const selection = designWindow()?.getSelection();
  if (!selection) return;
  if (action === "copy") {
    await window.htmlStudioAPI.writeClipboard(designClipboardPayload());
    return;
  }
  if (action === "selectAll") {
    const frameDocument = designDocument();
    if (!frameDocument?.body) return;
    const range = frameDocument.createRange();
    range.selectNodeContents(frameDocument.body);
    selection.removeAllRanges();
    selection.addRange(range);
    state.savedRange = range.cloneRange();
    return;
  }
  if (isGuide()) {
    showToast("使用说明为只读页面。");
    return;
  }
  if (action === "paste" || action === "pastePlainText") {
    await pasteIntoDesign(action === "pastePlainText");
    return;
  }
  const frameDocument = prepareCommand();
  if (!frameDocument) return;
  if (action === "cut") {
    await window.htmlStudioAPI.writeClipboard(designClipboardPayload());
    refocusDesign();
    frameDocument.execCommand("delete", false);
    repairSelection();
    captureDesignHTML("剪切内容");
  } else if (action === "delete") {
    frameDocument.execCommand("delete", false);
    repairSelection();
    captureDesignHTML("删除内容");
  } else if (action === "undo" || action === "redo") {
    frameDocument.execCommand(action, false);
    repairSelection();
    captureDesignHTML(action === "undo" ? "撤销" : "重做");
  }
}

async function pastePlainTextForActiveSurface() {
  hideContextMenu();
  if (workspaceState.activeEditor === "source") {
    workspaceState.contextSourceSelection = {
      start: elements.source.selectionStart,
      end: elements.source.selectionEnd
    };
    await sourceContextAction("pastePlainText");
  } else {
    await pasteIntoDesign(true);
  }
}

function runsFromNode(node, inherited = {}) {
  if (node.nodeType === 3) {
    return node.textContent ? [{ text: node.textContent, ...inherited }] : [];
  }
  if (node.nodeType !== 1) return [];
  const tag = node.tagName.toLowerCase();
  const style = {
    ...inherited,
    bold: inherited.bold || tag === "strong" || tag === "b",
    italic: inherited.italic || tag === "em" || tag === "i",
    underline: inherited.underline || tag === "u",
    strike: inherited.strike || tag === "s" || tag === "del"
  };
  if (node.style.color) {
    const color = node.style.color.match(/#([0-9a-f]{6})/i);
    if (color) style.color = color[1];
  }
  if (node.style.fontFamily) style.font = node.style.fontFamily.split(",")[0].replaceAll('"', "");
  if (node.style.fontSize) {
    const value = Number.parseFloat(node.style.fontSize);
    if (Number.isFinite(value)) {
      style.size = node.style.fontSize.endsWith("px") ? value * 0.75 : value;
    }
  }
  if (tag === "br") return [{ text: "\n", ...style }];
  if (tag === "a" && node.getAttribute("href")) {
    const children = Array.from(node.childNodes).flatMap((child) => runsFromNode(child, style));
    children.push({ text: ` (${node.getAttribute("href")})`, ...style });
    return children;
  }
  return Array.from(node.childNodes).flatMap((child) => runsFromNode(child, style));
}

function buildDOCXModel() {
  const documentValue = new DOMParser().parseFromString(state.html, "text/html");
  const blocks = [];
  function visit(element, listContext = null) {
    if (element.nodeType !== 1) return;
    const tag = element.tagName.toLowerCase();
    if (tag === "table") {
      blocks.push({
        type: "table",
        rows: Array.from(element.rows).map((row) => (
          Array.from(row.cells).map((cell) => ({
            text: cell.textContent.trim(),
            header: cell.tagName.toLowerCase() === "th"
          }))
        ))
      });
      return;
    }
    if (tag === "ul" || tag === "ol") {
      Array.from(element.children).forEach((child) => visit(child, {
        type: tag === "ol" ? "number" : "bullet",
        level: listContext ? listContext.level + 1 : 0
      }));
      return;
    }
    if (tag === "li") {
      blocks.push({
        type: "paragraph",
        list: listContext?.type || "bullet",
        level: listContext?.level || 0,
        runs: runsFromNode(element)
      });
      Array.from(element.children)
        .filter((child) => ["ul", "ol"].includes(child.tagName.toLowerCase()))
        .forEach((child) => visit(child, listContext));
      return;
    }
    if (/^h[1-6]$/.test(tag) || ["p", "blockquote", "pre"].includes(tag)) {
      blocks.push({
        type: "paragraph",
        heading: /^h[1-6]$/.test(tag) ? Number(tag[1]) : null,
        quote: tag === "blockquote",
        alignment: element.style.textAlign || "left",
        runs: runsFromNode(element)
      });
      return;
    }
    const blockChildren = Array.from(element.children).filter((child) => (
      /^(H[1-6]|P|DIV|SECTION|ARTICLE|BLOCKQUOTE|PRE|UL|OL|TABLE)$/.test(child.tagName)
    ));
    if (blockChildren.length) {
      blockChildren.forEach((child) => visit(child, listContext));
    } else if (element.textContent.trim()) {
      blocks.push({ type: "paragraph", runs: runsFromNode(element) });
    }
  }
  Array.from(documentValue.body.children).forEach((child) => visit(child));
  return { blocks };
}

function showGuide() {
  let guide = workspaceState.documents.find((documentValue) => isGuide(documentValue));
  if (!guide) {
    guide = createGuideDocument();
    workspaceState.documents.unshift(guide);
  }
  if (workspaceState.selectedDocumentId === guide.id) {
    refreshActiveDocument();
  } else {
    selectDocument(guide);
  }
}

async function newDocument() {
  const documentValue = createDocument();
  workspaceState.documents.push(documentValue);
  workspaceState.selectedDocumentId = documentValue.id;
  workspaceState.lastUserDocumentId = documentValue.id;
  refreshActiveDocument();
  persistWorkspace();
  await initializeHistory(documentValue, "创建文档", "文件");
}

async function openDocument() {
  try {
    const results = await window.htmlStudioAPI.openFile();
    if (!Array.isArray(results) || !results.length) return;
    let lastDocument = null;
    for (const result of results) {
      const isMarkdown = [".md", ".markdown"].includes(result.extension);
      const existing = !isMarkdown && workspaceState.documents.find((documentValue) => (
        documentValue.filePath?.toLowerCase() === result.filePath.toLowerCase()
      ));
      if (existing) {
        lastDocument = existing;
        continue;
      }
      const html = isMarkdown
        ? window.HTMLStudioConverters.markdownToHTML(result.content)
        : result.content;
      const documentValue = createDocument({
        html,
        filePath: isMarkdown ? null : result.filePath,
        importedName: isMarkdown
          ? result.filePath.split(/[\\/]/).pop().replace(/\.(md|markdown)$/i, ".html")
          : null,
        baseURL: isMarkdown ? null : result.baseURL,
        dirty: isMarkdown,
        savedHTML: isMarkdown ? "" : html
      });
      workspaceState.documents.push(documentValue);
      lastDocument = documentValue;
      await initializeHistory(
        documentValue,
        isMarkdown ? "导入 Markdown 文件" : "打开 HTML 文件",
        "文件"
      );
    }
    if (lastDocument) {
      workspaceState.selectedDocumentId = lastDocument.id;
      workspaceState.lastUserDocumentId = lastDocument.id;
      refreshActiveDocument();
      persistWorkspace();
      showToast(results.length > 1 ? `已在标签页中打开 ${results.length} 个文件。` : "文件已在新标签页中打开。");
    }
  } catch (error) {
    showToast(`打开失败：${error.message}`);
  }
}

async function saveDocument(saveAs = false) {
  const documentValue = activeDocument();
  if (isGuide(documentValue)) {
    showToast("使用说明是内置页面，无需保存。");
    return false;
  }
  try {
    const oldKey = documentValue.historyKey;
    const result = await window.htmlStudioAPI.saveHTML({
      content: documentValue.html,
      filePath: documentValue.filePath,
      saveAs,
      suggestedName: fileName(documentValue)
    });
    if (!result) return false;
    documentValue.filePath = result.filePath;
    documentValue.importedName = null;
    documentValue.baseURL = result.baseURL;
    documentValue.savedHTML = documentValue.html;
    updateDocumentInfo();
    setDirty(false, documentValue);
    if (oldKey) {
      const migrated = await window.htmlStudioAPI.migrateHistory({
        oldKey,
        filePath: documentValue.filePath,
        draftId: documentValue.id
      });
      documentValue.historyKey = migrated.key;
      documentValue.historyEntries = migrated.entries;
    }
    await appendHistory(
      documentValue,
      saveAs ? "另存为 HTML" : "保存 HTML",
      "文件",
      fileName(documentValue)
    );
    showToast("HTML 已保存。");
    return true;
  } catch (error) {
    showToast(`保存失败：${error.message}`);
    return false;
  }
}

async function exportMarkdown() {
  if (isGuide()) {
    showToast("请先选择需要导出的 HTML 文档。");
    return;
  }
  try {
    const markdown = window.HTMLStudioConverters.htmlToMarkdown(state.html);
    const result = await window.htmlStudioAPI.exportText({
      content: markdown,
      extension: "md",
      suggestedName: suggestedName("md")
    });
    if (result) showToast("Markdown 已导出。");
  } catch (error) {
    showToast(`Markdown 导出失败：${error.message}`);
  }
}

async function exportDOCX() {
  if (isGuide()) {
    showToast("请先选择需要导出的 HTML 文档。");
    return;
  }
  try {
    const result = await window.htmlStudioAPI.exportDOCX({
      model: buildDOCXModel(),
      suggestedName: suggestedName("docx")
    });
    if (result) showToast("Word 文档已导出。");
  } catch (error) {
    showToast(`Word 导出失败：${error.message}`);
  }
}

async function exportPDF() {
  if (isGuide()) {
    showToast("请先选择需要导出的 HTML 文档。");
    return;
  }
  const originalLabel = elements.exportPDFButton.textContent;
  elements.exportPDFButton.disabled = true;
  elements.exportPDFButton.textContent = "正在导出…";
  try {
    const result = await window.htmlStudioAPI.exportPDF({
      content: state.html,
      baseURL: state.baseURL,
      suggestedName: suggestedName("pdf")
    });
    if (result) showToast("PDF 已导出。");
  } catch (error) {
    showToast(`PDF 导出失败：${error.message}`);
  } finally {
    elements.exportPDFButton.textContent = originalLabel;
    updateDocumentControls();
  }
}

async function printDocument() {
  if (isGuide()) {
    showToast("请先选择需要打印的 HTML 文档。");
    return;
  }
  const originalLabel = elements.printButton.textContent;
  elements.printButton.disabled = true;
  elements.printButton.textContent = "准备打印…";
  try {
    const result = await window.htmlStudioAPI.printHTML({
      content: state.html,
      baseURL: state.baseURL
    });
    if (result && !result.canceled) showToast("打印任务已提交。");
  } catch (error) {
    showToast(`打印失败：${error.message}`);
  } finally {
    elements.printButton.textContent = originalLabel;
    updateDocumentControls();
  }
}

function renderHistory() {
  const documentValue = activeDocument();
  const newest = [...documentValue.historyEntries].reverse();
  if (!workspaceState.selectedHistoryId && newest[0]) {
    workspaceState.selectedHistoryId = newest[0].id;
  }
  elements.historyDocumentName.textContent = fileName(documentValue);
  elements.historyList.replaceChildren();
  newest.forEach((entry) => {
    const button = document.createElement("button");
    button.className = "history-entry";
    button.classList.toggle("selected", entry.id === workspaceState.selectedHistoryId);
    const action = document.createElement("strong");
    action.textContent = entry.action;
    const summary = document.createElement("span");
    summary.textContent = `${entry.source} · ${entry.summary}`;
    const timestamp = document.createElement("span");
    timestamp.textContent = new Date(entry.timestamp).toLocaleString("zh-CN");
    button.append(action, summary, timestamp);
    button.addEventListener("click", () => {
      workspaceState.selectedHistoryId = entry.id;
      renderHistory();
    });
    elements.historyList.appendChild(button);
  });
  const selected = newest.find((entry) => entry.id === workspaceState.selectedHistoryId);
  elements.historyAction.textContent = selected?.action || "尚无修改记录";
  elements.historySummary.textContent = selected?.summary || "编辑后会在这里保存可恢复快照。";
  elements.historyHTML.textContent = selected?.html || "";
  elements.restoreHistoryButton.disabled = !selected;
}

async function showHistory() {
  const documentValue = activeDocument();
  if (isGuide(documentValue)) {
    showToast("使用说明不写入修改历史。");
    return;
  }
  if (!documentValue.historyKey) await initializeHistory(documentValue);
  workspaceState.selectedHistoryId = documentValue.historyEntries.at(-1)?.id || null;
  renderHistory();
  elements.historyDialog.showModal();
}

async function exportHistory() {
  const documentValue = activeDocument();
  try {
    const result = await window.htmlStudioAPI.exportHistory({
      entries: documentValue.historyEntries,
      suggestedName: `${fileName(documentValue)}-修改日志.json`
    });
    if (result) showToast("修改日志已导出。");
  } catch (error) {
    showToast(`日志导出失败：${error.message}`);
  }
}

async function restoreSelectedHistory() {
  const documentValue = activeDocument();
  const entry = documentValue.historyEntries.find(
    (item) => item.id === workspaceState.selectedHistoryId
  );
  if (!entry || !window.confirm(
    "恢复到此版本？\n\n当前内容不会被删除；恢复操作本身也会写入修改日志。"
  )) return;
  const previousCount = documentValue.html.length;
  documentValue.html = entry.html;
  documentValue.dirty = documentValue.html !== documentValue.savedHTML;
  applyHTML(documentValue.html, { dirty: documentValue.dirty });
  await appendHistory(
    documentValue,
    "恢复历史版本",
    "历史",
    `${changeSummary(previousCount, documentValue.html.length)}；来源 ${new Date(entry.timestamp).toLocaleString("zh-CN")}`
  );
  renderHistory();
}

function applyWorkspaceMode(mode) {
  elements.workspace.className = `workspace mode-${mode}`;
  document.querySelectorAll("[data-mode]").forEach((button) => {
    button.classList.toggle("active", button.dataset.mode === mode);
  });
}

function setWorkspaceMode(mode) {
  if (isGuide()) return;
  workspaceState.mode = ["source", "split", "design"].includes(mode)
    ? mode
    : "split";
  applyWorkspaceMode(workspaceState.mode);
}

function clearFindState() {
  findState.key = "";
  findState.matches = [];
  findState.currentIndex = -1;
}

function findSearchKey(query) {
  return [
    activeDocument()?.id || "",
    workspaceState.activeEditor,
    elements.matchCase.checked ? "1" : "0",
    query
  ].join(":");
}

function comparableFindText(value) {
  const text = String(value || "");
  return elements.matchCase.checked ? text : text.toLocaleLowerCase();
}

function sourceFindMatches(query) {
  const needle = comparableFindText(query);
  const source = comparableFindText(elements.source.value);
  if (!needle) return [];
  const matches = [];
  let offset = 0;
  while (offset <= source.length - needle.length) {
    const index = source.indexOf(needle, offset);
    if (index < 0) break;
    matches.push({ start: index, end: index + String(query).length });
    offset = index + Math.max(1, needle.length);
  }
  return matches;
}

function searchableDesignTextNodes() {
  const frameDocument = designDocument();
  if (!frameDocument?.body) return [];
  const nodes = [];
  const walker = frameDocument.createTreeWalker(
    frameDocument.body,
    NodeFilter.SHOW_TEXT,
    {
      acceptNode(node) {
        if (!node.nodeValue?.length) return NodeFilter.FILTER_REJECT;
        const parent = node.parentElement;
        if (!parent || parent.closest(
          "script,style,noscript,textarea,[data-html-studio-ui]"
        )) return NodeFilter.FILTER_REJECT;
        const style = designWindow().getComputedStyle(parent);
        if (style.display === "none" || style.visibility === "hidden") {
          return NodeFilter.FILTER_REJECT;
        }
        return NodeFilter.FILTER_ACCEPT;
      }
    }
  );
  let node = walker.nextNode();
  while (node) {
    nodes.push(node);
    node = walker.nextNode();
  }
  return nodes;
}

function designFindMatches(query) {
  const needle = comparableFindText(query);
  if (!needle) return [];
  const matches = [];
  searchableDesignTextNodes().forEach((node) => {
    const source = comparableFindText(node.nodeValue);
    let offset = 0;
    while (offset <= source.length - needle.length) {
      const index = source.indexOf(needle, offset);
      if (index < 0) break;
      matches.push({ node, start: index, end: index + String(query).length });
      offset = index + Math.max(1, needle.length);
    }
  });
  return matches;
}

function buildFindMatches(query) {
  return workspaceState.activeEditor === "source"
    ? sourceFindMatches(query)
    : designFindMatches(query);
}

function selectFindMatch(index) {
  const match = findState.matches[index];
  if (!match) return false;
  if (workspaceState.activeEditor === "source") {
    elements.source.setSelectionRange(match.start, match.end);
    const style = getComputedStyle(elements.source);
    const lineHeight = Number.parseFloat(style.lineHeight) || 20;
    const line = elements.source.value.slice(0, match.start).split("\n").length - 1;
    elements.source.scrollTop = Math.max(
      0,
      line * lineHeight - elements.source.clientHeight / 2
    );
    workspaceState.contextSourceSelection = {
      start: match.start,
      end: match.end
    };
    return true;
  }

  if (!match.node?.isConnected) return false;
  const frameDocument = designDocument();
  const selection = designWindow()?.getSelection();
  if (!frameDocument || !selection) return false;
  const range = frameDocument.createRange();
  range.setStart(match.node, match.start);
  range.setEnd(match.node, match.end);
  selection.removeAllRanges();
  selection.addRange(range);
  state.savedRange = range.cloneRange();
  markActivePage(match.node);
  match.node.parentElement?.scrollIntoView({
    behavior: "smooth",
    block: "center",
    inline: "nearest"
  });
  return true;
}

function setFindStatus(result = {}) {
  const replaced = Number(result.replaced || 0);
  const total = Number(result.total || 0);
  const current = Number(result.current || 0);
  if (replaced > 0) {
    elements.findStatus.textContent = total > 0
      ? `已替换 ${replaced} 处 · 尚有 ${total} 处`
      : `已替换 ${replaced} 处`;
  } else if (!elements.findInput.value) {
    elements.findStatus.textContent = "输入查找内容";
  } else if (!total) {
    elements.findStatus.textContent = "未找到";
  } else {
    elements.findStatus.textContent = `${Math.max(1, current)} / ${total}`;
  }
}

function canReplaceFindMatches() {
  return !isGuide() && (
    workspaceState.activeEditor === "source" || Boolean(state.editEnabled)
  );
}

function updateFindControls() {
  const hasQuery = Boolean(elements.findInput.value);
  elements.findTarget.textContent = workspaceState.activeEditor === "source"
    ? "源码"
    : "页面";
  elements.findPreviousButton.disabled = !hasQuery;
  elements.findNextButton.disabled = !hasQuery;
  elements.replaceCurrentButton.disabled = !hasQuery || !canReplaceFindMatches();
  elements.replaceAllButton.disabled = !hasQuery || !canReplaceFindMatches();
}

function performFind(backwards = false, reset = false) {
  const query = elements.findInput.value;
  updateFindControls();
  if (!query) {
    clearFindState();
    setFindStatus();
    return { current: 0, total: 0, replaced: 0 };
  }
  const key = findSearchKey(query);
  const sameSearch = key === findState.key;
  const previousIndex = findState.currentIndex;
  const matches = buildFindMatches(query);
  findState.key = key;
  findState.matches = matches;
  if (!matches.length) {
    findState.currentIndex = -1;
    const result = { current: 0, total: 0, replaced: 0 };
    setFindStatus(result);
    return result;
  }
  if (!reset && sameSearch && previousIndex >= 0) {
    findState.currentIndex = backwards
      ? (previousIndex - 1 + matches.length) % matches.length
      : (previousIndex + 1) % matches.length;
  } else {
    findState.currentIndex = backwards ? matches.length - 1 : 0;
  }
  selectFindMatch(findState.currentIndex);
  const result = {
    current: findState.currentIndex + 1,
    total: matches.length,
    replaced: 0
  };
  setFindStatus(result);
  return result;
}

function selectedTextForFind() {
  if (workspaceState.activeEditor === "source") {
    return elements.source.value.slice(
      elements.source.selectionStart,
      elements.source.selectionEnd
    );
  }
  return designWindow()?.getSelection()?.toString() || "";
}

function openFindBar(withReplace = false) {
  hideContextMenu();
  elements.findBar.hidden = false;
  if (withReplace) elements.replaceRow.hidden = false;
  const selected = selectedTextForFind().replaceAll(/\r?\n/g, " ").trim();
  if (!elements.findInput.value && selected && selected.length <= 200) {
    elements.findInput.value = selected;
  }
  updateFindControls();
  if (elements.findInput.value) performFind(false, true);
  else setFindStatus();
  elements.findInput.focus({ preventScroll: true });
  elements.findInput.select();
}

function closeFindBar() {
  elements.findBar.hidden = true;
  clearFindState();
  setFindStatus();
}

function activateEditorSurface(surface) {
  const changed = workspaceState.activeEditor !== surface;
  workspaceState.activeEditor = surface;
  if (!elements.findBar.hidden) {
    updateFindControls();
    if (changed && elements.findInput.value) performFind(false, true);
  }
}

function replaceSourceRange(start, end, replacement, action) {
  elements.source.focus({ preventScroll: true });
  elements.source.setSelectionRange(start, end);
  const inserted = document.execCommand("insertText", false, replacement);
  if (!inserted) elements.source.setRangeText(replacement, start, end, "end");
  syncSourceEditor(action);
  elements.findInput.focus({ preventScroll: true });
}

function replaceCurrentMatch() {
  const query = elements.findInput.value;
  if (!query || !canReplaceFindMatches()) return;
  const key = findSearchKey(query);
  const previousIndex = key === findState.key && findState.currentIndex >= 0
    ? findState.currentIndex
    : 0;
  const matches = buildFindMatches(query);
  if (!matches.length) {
    clearFindState();
    setFindStatus({ total: 0 });
    return;
  }
  const index = Math.min(previousIndex, matches.length - 1);
  const match = matches[index];
  const replacement = elements.replaceInput.value;
  if (workspaceState.activeEditor === "source") {
    replaceSourceRange(match.start, match.end, replacement, "替换 HTML 源码");
  } else {
    match.node.replaceData(match.start, match.end - match.start, replacement);
    captureDesignHTML("替换页面文字");
    elements.findInput.focus({ preventScroll: true });
  }
  const remaining = buildFindMatches(query);
  findState.key = findSearchKey(query);
  findState.matches = remaining;
  findState.currentIndex = remaining.length ? Math.min(index, remaining.length - 1) : -1;
  if (findState.currentIndex >= 0) selectFindMatch(findState.currentIndex);
  setFindStatus({
    current: findState.currentIndex + 1,
    total: remaining.length,
    replaced: 1
  });
}

function replaceAllMatches() {
  const query = elements.findInput.value;
  if (!query || !canReplaceFindMatches()) return;
  const matches = buildFindMatches(query);
  if (!matches.length) {
    clearFindState();
    setFindStatus({ total: 0 });
    return;
  }
  const replacement = elements.replaceInput.value;
  if (workspaceState.activeEditor === "source") {
    let updated = "";
    let offset = 0;
    matches.forEach((match) => {
      updated += elements.source.value.slice(offset, match.start) + replacement;
      offset = match.end;
    });
    updated += elements.source.value.slice(offset);
    replaceSourceRange(
      0,
      elements.source.value.length,
      updated,
      `全部替换 HTML 源码（${matches.length} 处）`
    );
  } else {
    [...matches].reverse().forEach((match) => {
      match.node.replaceData(match.start, match.end - match.start, replacement);
    });
    captureDesignHTML(`全部替换页面文字（${matches.length} 处）`);
    elements.findInput.focus({ preventScroll: true });
  }
  const remaining = buildFindMatches(query);
  findState.key = findSearchKey(query);
  findState.matches = remaining;
  findState.currentIndex = -1;
  setFindStatus({ total: remaining.length, replaced: matches.length });
}

elements.source.addEventListener("focus", () => {
  activateEditorSurface("source");
});
elements.source.addEventListener("pointerdown", () => {
  activateEditorSurface("source");
});
elements.source.addEventListener("input", () => syncSourceEditor());
elements.source.addEventListener("contextmenu", (event) => {
  event.preventDefault();
  activateEditorSurface("source");
  workspaceState.contextSourceSelection = {
    start: elements.source.selectionStart,
    end: elements.source.selectionEnd
  };
  showContextMenu(event.clientX, event.clientY, "source");
});

elements.frame.addEventListener("load", () => {
  const frameDocument = designDocument();
  if (!frameDocument?.body) return;
  setDesignEditable();
  if (!elements.findBar.hidden && workspaceState.activeEditor === "design" &&
      elements.findInput.value) {
    performFind(false, true);
  }
  frameDocument.addEventListener("selectionchange", saveSelection);
  frameDocument.addEventListener("compositionstart", () => {
    if (isGuide()) return;
    state.isComposing = true;
    state.compositionAction = "中文输入";
    state.pendingAction = null;
    clearTimeout(state.visualCaptureTimer);
  }, true);
  frameDocument.addEventListener("compositionupdate", () => {
    if (!isGuide()) state.isComposing = true;
  }, true);
  frameDocument.addEventListener("compositionend", () => {
    if (isGuide()) return;
    state.isComposing = false;
    const action = state.compositionAction || "中文输入";
    state.compositionAction = null;
    state.pendingAction = action;
    requestAnimationFrame(() => {
      saveSelection();
      scheduleDesignCapture(action);
    });
  }, true);
  frameDocument.addEventListener("beforeinput", (event) => {
    if (isGuide()) return;
    if (event.isComposing || event.inputType === "insertCompositionText") {
      state.isComposing = true;
      state.compositionAction = "中文输入";
      return;
    }
    state.pendingAction = inputActionNames[event.inputType] ||
      (event.inputType?.startsWith("delete") ? "删除内容" : "编辑页面文字");
  }, true);
  frameDocument.addEventListener("input", (event) => {
    if (isGuide() || state.isComposing || event.isComposing ||
        event.inputType === "insertCompositionText") {
      return;
    }
    const action = state.pendingAction ||
      inputActionNames[event.inputType] ||
      "编辑页面文字";
    state.pendingAction = null;
    requestAnimationFrame(() => {
      repairSelection();
      scheduleDesignCapture(action);
    });
  }, true);
  frameDocument.addEventListener("keydown", (event) => {
    if (!event.ctrlKey || event.altKey || event.metaKey) return;
    const key = event.key.toLowerCase();
    if (key === "f" || key === "h") {
      event.preventDefault();
      activateEditorSurface("design");
      openFindBar(key === "h");
      return;
    }
    if (key === "g") {
      event.preventDefault();
      activateEditorSurface("design");
      if (elements.findBar.hidden || !elements.findInput.value) {
        openFindBar(false);
      } else {
        performFind(event.shiftKey);
      }
      return;
    }
    if (key === "v" && event.shiftKey) {
      event.preventDefault();
      workspaceState.activeEditor = "design";
      pastePlainTextForActiveSurface();
      return;
    }
    if (key !== "z" && key !== "y") return;
    event.preventDefault();
    workspaceState.activeEditor = "design";
    const command = key === "y" || event.shiftKey ? "redo" : "undo";
    executeCommand(command);
  }, true);
  frameDocument.addEventListener("cut", () => {
    state.pendingAction = "剪切内容";
  }, true);
  frameDocument.addEventListener("paste", () => {
    state.pendingAction = "粘贴内容";
  }, true);
  frameDocument.addEventListener("blur", saveSelection, true);
  frameDocument.addEventListener("pointerdown", (event) => {
    activateEditorSurface("design");
    markActivePage(event.target);
    hideContextMenu();
  }, true);
  frameDocument.addEventListener("contextmenu", (event) => {
    event.preventDefault();
    saveSelection();
    markActivePage(event.target);
    const bounds = elements.frame.getBoundingClientRect();
    showContextMenu(bounds.left + event.clientX, bounds.top + event.clientY, "design");
  }, true);
  frameDocument.addEventListener("click", (event) => {
    if (isGuide()) return;
    if (state.editEnabled && event.target.closest("a")) event.preventDefault();
  }, true);
});

document.querySelectorAll("[data-command]").forEach((button) => {
  button.addEventListener("mousedown", (event) => event.preventDefault());
  button.addEventListener("click", () => {
    workspaceState.activeEditor = "design";
    executeCommand(button.dataset.command);
  });
});

document.querySelector("#font-family").addEventListener("change", (event) => {
  executeCommand("fontName", event.target.value);
});
document.querySelector("#font-size").addEventListener("change", (event) => {
  setFontSize(Number(event.target.value));
});
document.querySelector("#block-format").addEventListener("change", (event) => {
  executeCommand("formatBlock", event.target.value);
});
document.querySelector("#foreground-color").addEventListener("change", (event) => {
  executeCommand("foreColor", event.target.value);
});
document.querySelector("#highlight-color").addEventListener("change", (event) => {
  executeCommand("hiliteColor", event.target.value);
});
document.querySelector("#link-button").addEventListener("click", () => {
  const value = window.prompt("输入链接地址：", "https://");
  if (value) executeCommand("createLink", value);
});
document.querySelector("#image-button").addEventListener("click", () => {
  const value = window.prompt("输入图片 URL 或相对路径：", "");
  if (value) executeCommand("insertImage", value);
});

document.querySelectorAll("[data-table-insert]").forEach((button) => {
  button.addEventListener("click", () => {
    const [rows, columns] = button.dataset.tableInsert.split(",").map(Number);
    insertTable(rows, columns);
    elements.tableMenu.open = false;
  });
});
document.querySelectorAll("[data-table-action]").forEach((button) => {
  button.addEventListener("click", () => {
    tableAction(button.dataset.tableAction);
    elements.tableMenu.open = false;
  });
});
document.querySelectorAll("[data-page-action]").forEach((button) => {
  button.addEventListener("click", () => {
    pageAction(button.dataset.pageAction);
    elements.pageMenu.open = false;
  });
});
document.querySelectorAll("[data-context-action]").forEach((button) => {
  button.addEventListener("mousedown", (event) => event.preventDefault());
  button.addEventListener("click", () => contextAction(button.dataset.contextAction));
});
document.querySelectorAll("[data-context-command]").forEach((button) => {
  button.addEventListener("mousedown", (event) => event.preventDefault());
  button.addEventListener("click", () => {
    hideContextMenu();
    activateEditorSurface("design");
    executeCommand(button.dataset.contextCommand, button.dataset.contextValue || null);
  });
});
document.querySelector("#context-foreground-color").addEventListener("change", (event) => {
  hideContextMenu();
  activateEditorSurface("design");
  executeCommand("foreColor", event.target.value);
});
document.querySelector("#context-highlight-color").addEventListener("change", (event) => {
  hideContextMenu();
  activateEditorSurface("design");
  executeCommand("hiliteColor", event.target.value);
});

elements.editToggle.addEventListener("change", () => {
  state.editEnabled = elements.editToggle.checked;
  setDesignEditable();
  updateFindControls();
  persistWorkspace();
});

document.querySelectorAll("[data-mode]").forEach((button) => {
  button.addEventListener("click", () => setWorkspaceMode(button.dataset.mode));
});

document.querySelector("#new-button").addEventListener("click", newDocument);
elements.addTabButton.addEventListener("click", newDocument);
document.querySelector("#open-button").addEventListener("click", openDocument);
document.querySelector("#save-button").addEventListener("click", () => saveDocument(false));
elements.undoButton.addEventListener("mousedown", (event) => event.preventDefault());
elements.redoButton.addEventListener("mousedown", (event) => event.preventDefault());
elements.undoButton.addEventListener("click", () => performHistoryCommand("undo"));
elements.redoButton.addEventListener("click", () => performHistoryCommand("redo"));
elements.findButton.addEventListener("click", () => openFindBar(false));
elements.findInput.addEventListener("input", () => performFind(false, true));
elements.findInput.addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    performFind(event.shiftKey);
  } else if (event.key === "Escape") {
    event.preventDefault();
    closeFindBar();
  }
});
elements.replaceInput.addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    replaceCurrentMatch();
  } else if (event.key === "Escape") {
    event.preventDefault();
    closeFindBar();
  }
});
elements.matchCase.addEventListener("change", () => performFind(false, true));
elements.findPreviousButton.addEventListener("click", () => performFind(true));
elements.findNextButton.addEventListener("click", () => performFind(false));
elements.toggleReplaceButton.addEventListener("click", () => {
  elements.replaceRow.hidden = !elements.replaceRow.hidden;
  if (!elements.replaceRow.hidden) {
    elements.replaceInput.focus({ preventScroll: true });
  }
});
elements.closeFindButton.addEventListener("click", closeFindBar);
elements.replaceCurrentButton.addEventListener("click", replaceCurrentMatch);
elements.replaceAllButton.addEventListener("click", replaceAllMatches);
document.querySelector("#export-markdown").addEventListener("click", exportMarkdown);
document.querySelector("#export-docx").addEventListener("click", exportDOCX);
document.querySelector("#export-pdf").addEventListener("click", exportPDF);
document.querySelector("#print-button").addEventListener("click", printDocument);
document.querySelector("#history-button").addEventListener("click", showHistory);
document.querySelector("#close-history-button").addEventListener("click", () => {
  elements.historyDialog.close();
});
document.querySelector("#export-history-button").addEventListener("click", exportHistory);
elements.restoreHistoryButton.addEventListener("click", restoreSelectedHistory);

document.addEventListener("mousedown", (event) => {
  if (!elements.contextMenu.contains(event.target)) hideContextMenu();
});
window.addEventListener("blur", hideContextMenu);
window.addEventListener("resize", hideContextMenu);

window.htmlStudioAPI.onMenuCommand((command) => {
  const handlers = {
    new: newDocument,
    open: openDocument,
    save: () => saveDocument(false),
    saveAs: () => saveDocument(true),
    exportMarkdown,
    exportDOCX,
    exportPDF,
    print: printDocument,
    showHistory,
    showGuide,
    undo: () => performHistoryCommand("undo"),
    redo: () => performHistoryCommand("redo"),
    pastePlainText: pastePlainTextForActiveSurface,
    find: () => openFindBar(false),
    findReplace: () => openFindBar(true),
    findNext: () => elements.findBar.hidden || !elements.findInput.value
      ? openFindBar(false)
      : performFind(false),
    findPrevious: () => elements.findBar.hidden || !elements.findInput.value
      ? openFindBar(false)
      : performFind(true)
  };
  handlers[command]?.();
});

window.addEventListener("beforeunload", persistWorkspace);

window.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && !elements.findBar.hidden) {
    event.preventDefault();
    closeFindBar();
    return;
  }
  if (!event.ctrlKey) return;
  const key = event.key.toLowerCase();
  if (!event.altKey && (key === "f" || key === "h")) {
    event.preventDefault();
    openFindBar(key === "h");
  } else if (!event.altKey && key === "g") {
    event.preventDefault();
    if (elements.findBar.hidden || !elements.findInput.value) openFindBar(false);
    else performFind(event.shiftKey);
  } else if (!event.altKey && event.shiftKey && key === "v") {
    event.preventDefault();
    pastePlainTextForActiveSurface();
  } else if (!event.altKey && key === "z") {
    event.preventDefault();
    performHistoryCommand(event.shiftKey ? "redo" : "undo");
  } else if (!event.altKey && key === "y") {
    event.preventDefault();
    performHistoryCommand("redo");
  } else if (event.altKey && key === "h") {
    event.preventDefault();
    showHistory();
  } else if (key === "n") {
    event.preventDefault();
    newDocument();
  } else if (key === "o") {
    event.preventDefault();
    openDocument();
  } else if (key === "s") {
    event.preventDefault();
    saveDocument(event.shiftKey);
  }
});

function restoreWorkspace() {
  let restored = null;
  try {
    restored = JSON.parse(localStorage.getItem(workspaceStorageKey) || "null");
  } catch {
    restored = null;
  }
  if (Array.isArray(restored?.documents) && restored.documents.length) {
    const documents = restored.documents.map(createDocument);
    workspaceState.lastUserDocumentId = documents.some(
      (documentValue) => documentValue.id === restored.selectedDocumentId
    )
      ? restored.selectedDocumentId
      : documents[0].id;
    const guide = createGuideDocument();
    workspaceState.documents = [guide, ...documents];
    workspaceState.selectedDocumentId = guide.id;
    showToast("已恢复上次的标签页和自动草稿。");
    return;
  }

  let legacyDraft = null;
  try {
    legacyDraft = JSON.parse(
      localStorage.getItem("htmlStudioWindowsDraft") || "null"
    );
  } catch {
    legacyDraft = null;
  }
  const initial = legacyDraft?.dirty && typeof legacyDraft.html === "string"
    ? createDocument({
      html: legacyDraft.html,
      filePath: legacyDraft.filePath,
      baseURL: legacyDraft.baseURL,
      dirty: true,
      savedHTML: ""
    })
    : createDocument();
  const guide = createGuideDocument();
  workspaceState.documents = [guide, initial];
  workspaceState.selectedDocumentId = guide.id;
  workspaceState.lastUserDocumentId = initial.id;
  localStorage.removeItem("htmlStudioWindowsDraft");
}

restoreWorkspace();
renderTabs();
refreshActiveDocument();
workspaceState.documents.forEach((documentValue) => {
  if (isGuide(documentValue)) return;
  initializeHistory(
    documentValue,
    documentValue.dirty ? "恢复自动草稿" : null,
    "文件"
  );
});
