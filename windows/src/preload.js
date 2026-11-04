const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("htmlStudioAPI", {
  openFile: () => ipcRenderer.invoke("file:open"),
  startupFiles: () => ipcRenderer.invoke("file:startup"),
  confirmMarkdownImport: (name) => ipcRenderer.invoke("file:confirmMarkdownImport", name),
  onOpenFiles: (callback) => {
    const handler = (_event, files) => callback(files);
    ipcRenderer.on("open-files", handler);
    return () => ipcRenderer.removeListener("open-files", handler);
  },
  saveHTML: (request) => ipcRenderer.invoke("file:saveHTML", request),
  confirmCloseDocument: (request) => ipcRenderer.invoke("file:confirmCloseDocument", request),
  exportText: (request) => ipcRenderer.invoke("file:exportText", request),
  exportDOCX: (request) => ipcRenderer.invoke("file:exportDOCX", request),
  exportPDF: (request) => ipcRenderer.invoke("file:exportPDF", request),
  printHTML: (request) => ipcRenderer.invoke("file:print", request),
  readClipboardText: () => ipcRenderer.invoke("clipboard:readText"),
  writeClipboardText: (value) => ipcRenderer.invoke("clipboard:writeText", value),
  readClipboard: () => ipcRenderer.invoke("clipboard:read"),
  writeClipboard: (value) => ipcRenderer.invoke("clipboard:write", value),
  loadHistory: (request) => ipcRenderer.invoke("history:load", request),
  appendHistory: (request) => ipcRenderer.invoke("history:append", request),
  migrateHistory: (request) => ipcRenderer.invoke("history:migrate", request),
  exportHistory: (request) => ipcRenderer.invoke("history:export", request),
  setWindowTitle: (title) => ipcRenderer.invoke("window:setTitle", title),
  onWindowCloseRequested: (callback) => {
    const handler = () => callback();
    ipcRenderer.on("window-close-requested", handler);
    return () => ipcRenderer.removeListener("window-close-requested", handler);
  },
  resolveWindowClose: (approved) => ipcRenderer.invoke("window:resolveClose", Boolean(approved)),
  onMenuCommand: (callback) => {
    const handler = (_event, command) => callback(command);
    ipcRenderer.on("menu-command", handler);
    return () => ipcRenderer.removeListener("menu-command", handler);
  }
});
