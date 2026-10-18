/* Standalone HTML snippets: inserted content works after saving, without editor assets. */
(function (root) {
  const catalog = [
    { id: "link", name: "链接", title: "链接文字", address: true },
    { id: "button", name: "按钮", title: "按钮文字", address: true },
    { id: "image", name: "图片", title: "图片说明", address: true, content: "" },
    { id: "text", name: "文本区块", content: "在这里输入正文内容。" },
    { id: "heading", name: "标题", title: "二级标题" },
    { id: "card", name: "卡片", title: "卡片标题", content: "在这里输入卡片内容。" },
    { id: "columns", name: "两栏布局", content: "左栏内容。\n右栏内容。" },
    { id: "quote", name: "提示 / 引用", title: "提示", content: "在这里输入提示或引用内容。" },
    { id: "divider", name: "分隔线" },
    { id: "details", name: "折叠详情", title: "点击展开详情", content: "在这里输入详情内容。" },
    { id: "input", name: "输入框", title: "字段名称", content: "请输入内容" },
    { id: "list", name: "项目列表", content: "第一项\n第二项\n第三项" }
  ];
  const escape = (value) => String(value ?? "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  }[c]));
  const lines = (value) => escape(value).replace(/\r?\n/g, "<br>");
  function address(value, image = false) {
    const url = String(value || "").trim();
    if (/[\u0000-\u001f\u007f]/.test(url)) throw new Error("地址不能包含换行或控制字符。");
    const scheme = url.match(/^([a-z][a-z\d+.-]*):/i)?.[1].toLowerCase();
    const allowed = image ? ["https", "http", "file"] : ["https", "http", "file", "mailto", "tel"];
    if (scheme && !allowed.includes(scheme) && !(image && /^data:image\//i.test(url))) {
      throw new Error(image ? "请输入图片地址、相对路径，或选择本地图片。" : "请输入网页地址、邮件地址、电话或相对路径。");
    }
    if (!url) throw new Error(image ? "请填写图片地址或选择本地图片。" : "请填写链接地址。");
    return escape(url);
  }
  function render(kind, values = {}) {
    const item = catalog.find((entry) => entry.id === kind);
    if (!item) throw new Error("未知组件。");
    const title = escape(values.title?.trim() || item.title || "");
    const content = String(values.content ?? item.content ?? "");
    const marker = `data-html-studio-component="${kind}"`;
    const target = values.newWindow ? ' target="_blank" rel="noopener noreferrer"' : "";
    const buttonStyle = "display:inline-block;padding:10px 20px;border:0;border-radius:8px;background:#2563eb;color:#fff;text-decoration:none;font:inherit;cursor:pointer";
    switch (kind) {
      case "link": return `<a ${marker} href="${address(values.address)}"${target}>${title}</a>`;
      case "button": return String(values.address || "").trim()
        ? `<a ${marker} role="button" href="${address(values.address)}"${target} style="${buttonStyle}">${title}</a>`
        : `<button ${marker} type="button" style="${buttonStyle}">${title}</button>`;
      case "image": return `<figure style="margin:16px 0"><img ${marker} src="${address(values.address, true)}" alt="${title}" style="max-width:100%;height:auto;border-radius:8px">${content.trim() ? `<figcaption style="font-size:14px;color:#64748b;margin-top:8px">${lines(content)}</figcaption>` : ""}</figure>`;
      case "text": return `<p ${marker}>${lines(content)}</p>`;
      case "heading": return `<h2 ${marker}>${title}</h2>`;
      case "card": return `<section ${marker} style="box-sizing:border-box;margin:16px 0;padding:24px;border:1px solid #cbd5e1;border-radius:12px;background:#f8fafc;color:#172033"><h3 style="margin:0 0 12px">${title}</h3><p style="margin:0">${lines(content)}</p></section>`;
      case "columns": {
        const columns = content.split(/\r?\n/);
        return `<section ${marker} style="display:flex;flex-wrap:wrap;gap:20px;margin:16px 0"><div style="flex:1 1 220px;min-width:0"><p>${lines(columns[0] || "左栏内容。")}</p></div><div style="flex:1 1 220px;min-width:0"><p>${lines(columns.slice(1).join("\n") || "右栏内容。")}</p></div></section>`;
      }
      case "quote": return `<blockquote ${marker} style="margin:16px 0;padding:16px 20px;border-left:4px solid #2563eb;background:#eff6ff;color:#172033"><strong>${title}</strong><p style="margin:8px 0 0">${lines(content)}</p></blockquote>`;
      case "divider": return `<hr ${marker} style="border:0;border-top:1px solid #cbd5e1;margin:24px 0">`;
      case "details": return `<details ${marker} open style="margin:16px 0;padding:16px;border:1px solid #cbd5e1;border-radius:8px"><summary style="cursor:pointer;font-weight:600">${title}</summary><p>${lines(content)}</p></details>`;
      case "input": return `<label ${marker} style="display:block;margin:16px 0"><span style="display:block;margin-bottom:8px">${title}</span><input type="text" placeholder="${escape(content)}" style="box-sizing:border-box;width:100%;padding:10px 12px;border:1px solid #94a3b8;border-radius:6px;font:inherit"></label>`;
      case "list": return `<ul ${marker}>${content.split(/\r?\n/).filter((line) => line.trim()).map((line) => `<li>${escape(line)}</li>`).join("")}</ul>`;
    }
  }
  root.HTMLStudioComponents = { catalog, render };
  if (typeof module !== "undefined") module.exports = root.HTMLStudioComponents;
})(typeof window === "undefined" ? globalThis : window);
