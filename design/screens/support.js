// Local preview shim for .dc.html artboards (not the real runtime).
(function () {
  window.DCLogic = class {
    constructor(p) { this.props = p || {}; this.state = {}; }
    setState(s) { Object.assign(this.state, typeof s === 'function' ? s(this.state) : s); if (this.__r) this.__r(); }
  };
  function get(scope, path) {
    path = path.trim();
    if (path === 'true') return true;
    if (path === 'false') return false;
    return path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), scope);
  }
  function interp(str, scope) {
    const m = str.match(/^\{\{([^}]+)\}\}$/);
    if (m) return get(scope, m[1]);
    return str.replace(/\{\{([^}]+)\}\}/g, (_, p) => { const v = get(scope, p); return v == null ? '' : v; });
  }
  function proc(node, scope, out) {
    if (node.nodeType === 3) { const v = interp(node.textContent, scope); out.appendChild(document.createTextNode(v == null ? '' : String(v))); return; }
    if (node.nodeType !== 1) return;
    const tag = node.tagName.toLowerCase();
    if (tag === 'sc-for') {
      const list = get(scope, node.getAttribute('list').replace(/[{}]/g, '')) || [];
      const as = node.getAttribute('as');
      list.forEach((it) => { const s = Object.create(scope); s[as] = it; node.childNodes.forEach((c) => proc(c, s, out)); });
      return;
    }
    if (tag === 'sc-if') {
      const v = get(scope, node.getAttribute('value').replace(/[{}]/g, ''));
      if (v && v !== 'false') node.childNodes.forEach((c) => proc(c, scope, out));
      return;
    }
    const el = node.namespaceURI === 'http://www.w3.org/2000/svg' ? document.createElementNS(node.namespaceURI, node.tagName) : document.createElement(node.tagName);
    for (const a of node.attributes) {
      if (/^hint-/.test(a.name)) continue;
      const v = interp(a.value, scope);
      if (/^on[a-z]+$/i.test(a.name)) { if (typeof v === 'function') el.addEventListener(a.name.slice(2).toLowerCase(), v); continue; }
      if (v === false || v == null) continue;
      if (a.name === 'href' && a.namespaceURI) el.setAttributeNS(a.namespaceURI, a.name, v);
      else el.setAttribute(a.name, v === true ? '' : String(v));
    }
    const kids = tag === 'template' ? node.content.childNodes : node.childNodes;
    kids.forEach((c) => proc(c, scope, el));
    out.appendChild(el);
  }
  document.addEventListener('DOMContentLoaded', () => {
    const x = document.querySelector('x-dc');
    const helmet = x.querySelector('helmet');
    if (helmet) { Array.from(helmet.childNodes).forEach((n) => document.head.appendChild(n)); helmet.remove(); }
    const tmpl = Array.from(x.childNodes).map((n) => n.cloneNode(true));
    const code = document.querySelector('script[data-dc-script]').textContent;
    const C = new Function('DCLogic', code + '\nreturn Component;')(window.DCLogic);
    const inst = new C({});
    inst.__r = () => {
      const scope = Object.assign({}, inst.renderVals());
      const frag = document.createDocumentFragment();
      tmpl.forEach((n) => proc(n, scope, frag));
      x.innerHTML = '';
      x.appendChild(frag);
    };
    inst.__r();
    document.body.dataset.ready = '1';
  });
})();
