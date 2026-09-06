window.HTMLStudioGuideHTML = `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>HTML Studio 使用说明</title>
  <style>
    :root {
      color-scheme: light;
      --ink: #14213d;
      --muted: #5b6780;
      --line: #dce4f0;
      --blue: #2563eb;
      --blue-soft: #eff6ff;
      --amber: #c35a05;
      --amber-soft: #fff7ed;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      color: var(--ink);
      background:
        radial-gradient(circle at 85% 0%, #dbeafe 0, transparent 28rem),
        linear-gradient(180deg, #f8fbff 0, #eef3f9 100%);
      font: 16px/1.7 "Segoe UI", "Microsoft YaHei", sans-serif;
    }
    main {
      width: min(1040px, calc(100% - 48px));
      margin: 0 auto;
      padding: 48px 0 72px;
    }
    .hero {
      padding: 38px 42px;
      border: 1px solid rgba(37, 99, 235, .18);
      border-radius: 24px;
      background: rgba(255, 255, 255, .9);
      box-shadow: 0 22px 60px rgba(30, 64, 175, .11);
    }
    .eyebrow {
      margin: 0 0 8px;
      color: var(--blue);
      font-size: 13px;
      font-weight: 800;
      letter-spacing: .14em;
    }
    h1 {
      margin: 0;
      font-size: clamp(34px, 5vw, 54px);
      line-height: 1.14;
      letter-spacing: -.04em;
    }
    .lead {
      max-width: 760px;
      margin: 16px 0 0;
      color: var(--muted);
      font-size: 18px;
    }
    .close-tip {
      display: inline-flex;
      margin-top: 24px;
      padding: 9px 14px;
      border-radius: 999px;
      color: #1746a2;
      background: var(--blue-soft);
      font-weight: 700;
    }
    h2 {
      margin: 42px 0 16px;
      font-size: 24px;
      letter-spacing: -.02em;
    }
    .steps, .features {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 16px;
    }
    .card {
      min-height: 178px;
      padding: 22px;
      border: 1px solid var(--line);
      border-radius: 18px;
      background: rgba(255, 255, 255, .88);
    }
    .card strong {
      display: block;
      margin-bottom: 7px;
      font-size: 18px;
    }
    .card p { margin: 0; color: var(--muted); }
    .number {
      display: grid;
      width: 34px;
      height: 34px;
      margin-bottom: 14px;
      place-items: center;
      border-radius: 10px;
      color: white;
      background: var(--blue);
      font-weight: 800;
    }
    .note {
      margin-top: 18px;
      padding: 20px 22px;
      border-left: 5px solid #f59e0b;
      border-radius: 12px;
      color: #6b3a08;
      background: var(--amber-soft);
    }
    .note strong { color: var(--amber); }
    table {
      width: 100%;
      overflow: hidden;
      border: 1px solid var(--line);
      border-collapse: collapse;
      border-radius: 16px;
      background: white;
    }
    th, td {
      padding: 13px 16px;
      border-bottom: 1px solid var(--line);
      text-align: left;
    }
    th { color: #40516f; background: #f4f7fb; }
    tr:last-child td { border-bottom: 0; }
    kbd {
      padding: 3px 7px;
      border: 1px solid #bac7d8;
      border-bottom-width: 2px;
      border-radius: 6px;
      background: #f8fafc;
      font: 12px Consolas, monospace;
    }
    footer {
      margin-top: 34px;
      color: var(--muted);
      text-align: center;
    }
    @media (max-width: 800px) {
      main { width: min(100% - 24px, 1040px); padding-top: 20px; }
      .hero { padding: 26px; }
      .steps, .features { grid-template-columns: 1fr; }
    }
  </style>
</head>
<body>
  <main>
    <section class="hero">
      <p class="eyebrow">HTML STUDIO · WINDOWS 0.3.10</p>
      <h1>从源码到所见即所得，<br>在一个窗口完成。</h1>
      <p class="lead">HTML Studio 可打开、实时预览和编辑 HTML，并导出 Markdown、Word 与 PDF，或打开 Windows 系统打印对话框。右侧页面支持中文输入法和类似 Word 的格式工具。</p>
      <span class="close-tip">本说明是独立标签页，点击标签上的 × 即可关闭</span>
    </section>

    <h2>三步开始</h2>
    <section class="steps">
      <article class="card">
        <span class="number">1</span>
        <strong>打开或新建</strong>
        <p>点击顶部“打开”选择一个或多个 HTML / Markdown 文件；也可点击“新建”或标签栏的 ＋。</p>
      </article>
      <article class="card">
        <span class="number">2</span>
        <strong>直接编辑页面</strong>
        <p>在右侧页面点击文字后输入。可选中文字，再用工具栏修改字体、字号、字形、颜色、段落和对齐。</p>
      </article>
      <article class="card">
        <span class="number">3</span>
        <strong>保存或转换</strong>
        <p>保存为 HTML；需要交换格式时，可导出 Markdown、Word、保留页面样式的 A4 PDF，或直接打印当前文档。</p>
      </article>
    </section>

    <div class="note">
      <strong>中文输入：</strong>使用微软拼音、搜狗等输入法时，拼音候选阶段不会同步或改写页面；确认候选文字后才会记录到 HTML 和修改历史。
    </div>

    <h2>编辑与恢复</h2>
    <section class="features">
      <article class="card">
        <strong>Word 式工具栏</strong>
        <p>支持字体、字号、粗体、斜体、下划线、颜色、段落、列表、缩进、链接、图片和表格行列编辑。</p>
      </article>
      <article class="card">
        <strong>右键与分页</strong>
        <p>源码和页面均提供右键菜单。页面右侧滚动条可直接拖动；页面菜单支持复制、追加、从光标处拆页，并可修改页面或表格底色。</p>
      </article>
      <article class="card">
        <strong>修改历史</strong>
        <p>每个文档独立记录最近 120 次修改快照，可查看、恢复旧版本，并导出 JSON 日志留存。</p>
      </article>
      <article class="card">
        <strong>查找与替换</strong>
        <p>根据最后使用的源码或页面区域查找文字，可循环定位、区分大小写，并替换当前匹配或一次替换全部。</p>
      </article>
    </section>

    <h2>常用快捷键</h2>
    <table>
      <thead><tr><th>操作</th><th>快捷键</th><th>说明</th></tr></thead>
      <tbody>
        <tr><td>新建</td><td><kbd>Ctrl</kbd> + <kbd>N</kbd></td><td>新建一个可编辑标签页</td></tr>
        <tr><td>打开</td><td><kbd>Ctrl</kbd> + <kbd>O</kbd></td><td>可一次选择多个文件</td></tr>
        <tr><td>保存</td><td><kbd>Ctrl</kbd> + <kbd>S</kbd></td><td>首次保存时选择位置</td></tr>
        <tr><td>另存为</td><td><kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd></td><td>保留原文件并创建副本</td></tr>
        <tr><td>粘贴为纯文本</td><td><kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>V</kbd></td><td>移除剪贴板中的字体、颜色和其他 HTML 格式</td></tr>
        <tr><td>查找</td><td><kbd>Ctrl</kbd> + <kbd>F</kbd></td><td>在当前源码或可视化页面中查找</td></tr>
        <tr><td>查找与替换</td><td><kbd>Ctrl</kbd> + <kbd>H</kbd></td><td>替换当前匹配或全部匹配</td></tr>
        <tr><td>下一处 / 上一处</td><td><kbd>Ctrl</kbd> + <kbd>G</kbd> / <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>G</kbd></td><td>循环定位匹配内容</td></tr>
        <tr><td>修改历史</td><td><kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>H</kbd></td><td>查看日志与恢复快照</td></tr>
        <tr><td>导出 PDF</td><td><kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>P</kbd></td><td>按 A4 保留 CSS、背景和表格，并避免正文被分页线截断</td></tr>
      </tbody>
    </table>

    <footer>关闭后可随时通过菜单“帮助 → 使用说明”重新打开本页。</footer>
  </main>
</body>
</html>`;
