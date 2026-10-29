() => {
  // Style probe for /ui-add. Paste as the browser_evaluate function, or run
  // with node + playwright (see ui-add.md). Reads computed styles only:
  // no images, logos or copy are collected.
  const vis = el => { const r = el.getBoundingClientRect(); const s = getComputedStyle(el);
    return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none' && +s.opacity > 0; };
  const tally = () => new Map();
  const add = (m, k, w = 1) => { if (k && k !== 'none' && k !== 'normal' && k !== '0px') m.set(k, (m.get(k) || 0) + w); };
  const top = (m, n = 12) => [...m].sort((a, b) => b[1] - a[1]).slice(0, n).map(([v, c]) => ({ v, c: Math.round(c) }));
  const clear = c => !c || c === 'transparent' || /rgba\([^)]*,\s*0\)$/.test(c);
  const all = [...document.body.querySelectorAll('*')].filter(vis).slice(0, 4000);
  const text = tally(), bg = tally(), border = tally(), fam = tally(), radius = tally(), shadow = tally(),
        space = tally(), gap = tally(), bw = tally(), maxw = tally();
  for (const el of all) {
    const s = getComputedStyle(el), r = el.getBoundingClientRect();
    const own = [...el.childNodes].filter(n => n.nodeType === 3).map(n => n.textContent.trim()).join('');
    if (own) { add(text, s.color, own.length); add(fam, s.fontFamily, own.length); }
    if (!clear(s.backgroundColor)) add(bg, s.backgroundColor, Math.sqrt(r.width * r.height));
    if (parseFloat(s.borderTopWidth) > 0 && !clear(s.borderTopColor)) { add(border, s.borderTopColor); add(bw, s.borderTopWidth + ' ' + s.borderTopStyle); }
    radius.set(s.borderTopLeftRadius, (radius.get(s.borderTopLeftRadius) || 0) + 1); add(shadow, s.boxShadow); // 0px counts: square corners are a style
    for (const p of ['paddingTop', 'paddingLeft', 'marginTop', 'marginBottom']) add(space, s[p]);
    add(gap, s.rowGap); add(gap, s.columnGap);
    if (s.maxWidth !== 'none' && s.marginLeft === s.marginRight && parseFloat(s.marginLeft) > 0) add(maxw, s.maxWidth);
  }
  const pick = ['fontFamily', 'fontSize', 'fontWeight', 'lineHeight', 'letterSpacing', 'textTransform', 'color'];
  const sample = sel => { const el = [...document.querySelectorAll(sel)].find(vis); if (!el) return null;
    const s = getComputedStyle(el); return Object.fromEntries(pick.map(k => [k, s[k]])); };
  const type = {}; for (const sel of ['h1', 'h2', 'h3', 'h4', 'p', 'li', 'a', 'small', 'label', 'nav a', 'footer', 'button']) type[sel] = sample(sel);
  const comp = (sel, limit = 6) => { const seen = new Map();
    for (const el of [...document.querySelectorAll(sel)].filter(vis)) { const s = getComputedStyle(el);
      const k = { bg: s.backgroundColor, color: s.color, border: s.borderTopWidth + ' ' + s.borderTopStyle + ' ' + s.borderTopColor,
        radius: s.borderTopLeftRadius, padding: s.padding, fontSize: s.fontSize, fontWeight: s.fontWeight,
        textTransform: s.textTransform, letterSpacing: s.letterSpacing, shadow: s.boxShadow, height: Math.round(el.getBoundingClientRect().height) + 'px' };
      const key = JSON.stringify(k); seen.set(key, (seen.get(key) || 0) + 1); }
    return [...seen].sort((a, b) => b[1] - a[1]).slice(0, limit).map(([k, c]) => ({ ...JSON.parse(k), count: c })); };
  const vars = {}, media = new Set(), faces = new Set();
  for (const sh of document.styleSheets) { let rules; try { rules = sh.cssRules; } catch { continue; }
    const walk = rs => { for (const r of rs) {
      if (r.selectorText && /(^|,)\s*(:root|html)\s*(,|$)/.test(r.selectorText)) for (const p of r.style) if (p.startsWith('--')) vars[p] = r.style.getPropertyValue(p).trim();
      if (r.media && r.conditionText) media.add(r.conditionText);
      if (r.type === 5) faces.add(r.style.getPropertyValue('font-family').replace(/["']/g, ''));
      if (r.cssRules) walk(r.cssRules); } };
    walk(rules); }
  const page = getComputedStyle(document.body);
  return {
    url: location.href, viewport: innerWidth,
    page: { bg: clear(page.backgroundColor) ? getComputedStyle(document.documentElement).backgroundColor : page.backgroundColor, color: page.color, font: page.fontFamily, fontSize: page.fontSize, lineHeight: page.lineHeight },
    colors: { text: top(text), background: top(bg), border: top(border, 8) },
    fonts: { used: top(fam, 6), fontFace: [...faces].slice(0, 12) },
    type,
    components: { buttons: comp('button, [role=button], a[class*=btn], a[class*=button], input[type=submit]'),
      inputs: comp('input:not([type=hidden]):not([type=submit]):not([type=checkbox]):not([type=radio]), textarea, select', 4),
      nav: comp('header, nav', 3), footer: comp('footer', 2) },
    shape: { radius: top(radius, 8), shadow: top(shadow, 6), borderWidth: top(bw, 6) },
    spacing: { padMargin: top(space, 14), gap: top(gap, 8), containerMaxWidth: top(maxw, 5) },
    breakpoints: [...media].filter(m => /width/.test(m)).slice(0, 20),
    cssVariables: Object.fromEntries(Object.entries(vars).slice(0, 120))
  };
}
