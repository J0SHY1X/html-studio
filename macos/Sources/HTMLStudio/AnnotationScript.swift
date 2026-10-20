import Foundation

enum AnnotationScript {
    static let source = #"""
/* Shared HTML annotation format. The native Mac bridge embeds this same engine. */
(function (root) {
  function create(doc) {
    const selector = '[data-html-studio-comment][data-html-studio-note]';
    const win = doc.defaultView;
    function ensureStyle(root) {
      if (!root.querySelector(selector)) {root.querySelector('[data-html-studio-comment-style]')?.remove();return;}
      if (root.querySelector('[data-html-studio-comment-style]')) return;
      const style = doc.createElement('style');
      style.setAttribute('data-html-studio-comment-style', 'true');
      style.textContent = selector + '{background-color:#fff0ad;text-decoration:underline dotted #b7791f;text-underline-offset:3px;}';
      (root.querySelector('head') || doc.head).append(style);
    }
    function list() {
      const result = new Map();
      doc.querySelectorAll(selector).forEach(node => {
        const id = node.getAttribute('data-html-studio-comment');
        if (!result.has(id)) result.set(id, { id, note: node.getAttribute('data-html-studio-note'), text: '' });
        result.get(id).text += node.textContent;
      });
      return [...result.values()];
    }
    function target() {
      const selection = win.getSelection();
      if (!selection?.rangeCount) return null;
      const range = selection.getRangeAt(0).cloneRange();
      if (!doc.body.contains(range.commonAncestorContainer)) return null;
      if (range.collapsed) {
        const element = range.startContainer.nodeType === 3 ? range.startContainer.parentElement : range.startContainer;
        const paragraph = element.closest('p,li,h1,h2,h3,h4,h5,h6,blockquote,td,th,pre');
        if (!paragraph) return null;
        range.selectNodeContents(paragraph);
      }
      return range.toString().trim() ? range : null;
    }
    function add(range, value) {
      const note = String(value || '').trim();
      if (!range || !note || !doc.body.contains(range.commonAncestorContainer)) return false;
      const holder = doc.createElement('div');
      holder.append(range.cloneContents());
      if (holder.querySelector(selector)) return false;
      const ancestor = range.commonAncestorContainer.nodeType === 3 ? range.commonAncestorContainer.parentElement : range.commonAncestorContainer;
      if (ancestor.closest(selector)) return false;
      const walker = doc.createTreeWalker(holder, 4);
      const texts = [];
      while (walker.nextNode()) {
        const node = walker.currentNode;
        if (node.textContent.trim() && !node.parentElement.closest('script,style')) texts.push(node);
      }
      if (!texts.length) return false;
      const id = 'comment-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2);
      for (const text of texts) {
        const marker = doc.createElement('span');
        marker.setAttribute('data-html-studio-comment', id);
        marker.setAttribute('data-html-studio-note', note);
        marker.title = note;
        marker.style.cssText = 'background-color:#fff0ad;text-decoration:underline dotted #b7791f;text-underline-offset:3px;';
        text.replaceWith(marker);marker.append(text);
      }
      doc.body.focus({preventScroll:true});
      const selection = win.getSelection();selection.removeAllRanges();selection.addRange(range);
      const success = doc.execCommand('insertHTML', false, holder.innerHTML);
      if (success) ensureStyle(doc);
      return success;
    }
    function remove(id) {
      const nodes = [...doc.querySelectorAll(selector)].filter(node => node.getAttribute('data-html-studio-comment') === id);
      for (const node of nodes) node.replaceWith(...node.childNodes);
      return nodes.length > 0;
    }
    function visible(show) {
      ensureStyle(doc);
      let style = doc.querySelector('[data-html-studio-ui="comment-visibility"]');
      if (!style) {
        style = doc.createElement('style');style.dataset.htmlStudioUi = 'comment-visibility';doc.head.append(style);
      }
      style.textContent = show ? '' : selector + '{background-color:transparent!important;text-decoration:none!important;}';
      doc.querySelectorAll(selector).forEach(node => {
        if (show) node.title = node.getAttribute('data-html-studio-note');
        else node.removeAttribute('title');
      });
    }
    function prepareClone(clone) {
      ensureStyle(clone);
      clone.querySelectorAll(selector).forEach(node => {node.title = node.getAttribute('data-html-studio-note');});
    }
    function reveal(id) {
      const node = [...doc.querySelectorAll(selector)].find(node => node.getAttribute('data-html-studio-comment') === id);
      node?.scrollIntoView({block:'center',behavior:'smooth'});
    }
    return {list,target,add,remove,visible,prepareClone,reveal};
  }
  root.HTMLStudioAnnotations = {create};
})(typeof window !== 'undefined' ? window : globalThis);
"""#
}
