(function exposeConverters() {
  function escapeHTML(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;");
  }

  function inlineMarkdown(value) {
    let result = escapeHTML(value);
    result = result.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
    result = result.replace(/\*(.+?)\*/g, "<em>$1</em>");
    result = result.replace(/`(.+?)`/g, "<code>$1</code>");
    result = result.replace(
      /\[([^\]]+)\]\(([^)]+)\)/g,
      '<a href="$2">$1</a>'
    );
    return result;
  }

  function markdownToHTML(markdown) {
    const lines = String(markdown).replaceAll("\r\n", "\n").split("\n");
    const output = [];
    let listType = null;
    let inCode = false;
    let codeLines = [];

    const closeList = () => {
      if (listType) output.push(`</${listType}>`);
      listType = null;
    };

    for (const line of lines) {
      if (line.startsWith("```")) {
        closeList();
        if (inCode) {
          output.push(`<pre><code>${escapeHTML(codeLines.join("\n"))}</code></pre>`);
          codeLines = [];
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        codeLines.push(line);
        continue;
      }

      const heading = line.match(/^(#{1,6})\s+(.+)$/);
      const bullet = line.match(/^\s*[-*]\s+(.+)$/);
      const numbered = line.match(/^\s*\d+\.\s+(.+)$/);
      if (heading) {
        closeList();
        const level = heading[1].length;
        output.push(`<h${level}>${inlineMarkdown(heading[2])}</h${level}>`);
      } else if (bullet || numbered) {
        const nextType = bullet ? "ul" : "ol";
        if (listType !== nextType) {
          closeList();
          listType = nextType;
          output.push(`<${listType}>`);
        }
        output.push(`<li>${inlineMarkdown((bullet || numbered)[1])}</li>`);
      } else if (!line.trim()) {
        closeList();
      } else {
        closeList();
        output.push(`<p>${inlineMarkdown(line)}</p>`);
      }
    }
    closeList();

    return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Imported Markdown</title>
  <style>
    body { max-width: 780px; margin: 48px auto; padding: 0 24px; font: 17px/1.7 "Segoe UI", "Microsoft YaHei", sans-serif; }
    img { max-width: 100%; }
    pre { padding: 16px; overflow: auto; border-radius: 8px; background: #f3f4f6; }
  </style>
</head>
<body>
${output.join("\n")}
</body>
</html>`;
  }

  function htmlToMarkdown(html) {
    const documentValue = new DOMParser().parseFromString(String(html), "text/html");

    function convert(node, context = {}) {
      if (node.nodeType === Node.TEXT_NODE) {
        return node.textContent.replace(/\s+/g, " ");
      }
      if (node.nodeType !== Node.ELEMENT_NODE) return "";

      const tag = node.tagName.toLowerCase();
      const children = () => Array.from(node.childNodes)
        .map((child) => convert(child, context))
        .join("");

      if (/^h[1-6]$/.test(tag)) {
        return `\n${"#".repeat(Number(tag[1]))} ${children().trim()}\n\n`;
      }
      if (tag === "p" || tag === "div" || tag === "section" || tag === "article") {
        return `\n${children().trim()}\n\n`;
      }
      if (tag === "br") return "\n";
      if (tag === "strong" || tag === "b") return `**${children()}**`;
      if (tag === "em" || tag === "i") return `*${children()}*`;
      if (tag === "del" || tag === "s") return `~~${children()}~~`;
      if (tag === "code" && node.parentElement?.tagName.toLowerCase() !== "pre") {
        return `\`${children()}\``;
      }
      if (tag === "pre") return `\n\`\`\`\n${node.textContent}\n\`\`\`\n\n`;
      if (tag === "a") return `[${children()}](${node.getAttribute("href") || ""})`;
      if (tag === "img") {
        return `![${node.getAttribute("alt") || ""}](${node.getAttribute("src") || ""})`;
      }
      if (tag === "blockquote") {
        return `\n${children().trim().split("\n").map((line) => `> ${line}`).join("\n")}\n\n`;
      }
      if (tag === "li") {
        const marker = context.ordered ? `${context.index || 1}.` : "-";
        return `${marker} ${children().trim()}\n`;
      }
      if (tag === "ul" || tag === "ol") {
        const ordered = tag === "ol";
        return `\n${Array.from(node.children).map((child, index) => (
          convert(child, { ordered, index: index + 1 })
        )).join("")}\n`;
      }
      if (tag === "table") {
        const rows = Array.from(node.rows).map((row) => (
          Array.from(row.cells).map((cell) => cell.textContent.trim().replaceAll("|", "\\|"))
        ));
        if (!rows.length) return "";
        const width = Math.max(...rows.map((row) => row.length));
        const normalized = rows.map((row) => (
          Array.from({ length: width }, (_, index) => row[index] || "")
        ));
        const header = normalized[0];
        const separator = Array(width).fill("---");
        return `\n| ${header.join(" | ")} |\n| ${separator.join(" | ")} |\n${normalized.slice(1).map((row) => `| ${row.join(" | ")} |`).join("\n")}\n\n`;
      }
      if (tag === "script" || tag === "style") return "";
      return children();
    }

    return convert(documentValue.body)
      .replace(/[ \t]+\n/g, "\n")
      .replace(/\n{3,}/g, "\n\n")
      .trim() + "\n";
  }

  window.HTMLStudioConverters = {
    htmlToMarkdown,
    markdownToHTML
  };
})();
