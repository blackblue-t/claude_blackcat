// Optional CLI fallback for /ui-add when the Playwright MCP is not available.
// Needs the playwright npm package (with its browser) installed globally:
//   NODE_PATH="$(npm root -g)" PROBE=<this dir>/extract-style.js node probe-cli.js <url> <out-dir>
// Writes <out-dir>/probe.json, shot-1440.png and shot-390.png.
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const [url, out] = process.argv.slice(2);
  const fn = fs.readFileSync(process.env.PROBE, 'utf8');
  const proxy = process.env.HTTPS_PROXY && !/localhost|127\.0\.0\.1/.test(url) ? { server: process.env.HTTPS_PROXY, bypass: 'localhost,127.0.0.1' } : undefined;
  const b = await chromium.launch({ proxy });
  const results = {};
  for (const w of [1440, 390]) {
    const ctx = await b.newContext({ viewport: { width: w, height: w > 500 ? 900 : 844 }, ignoreHTTPSErrors: true });
    const p = await ctx.newPage();
    await p.goto(url, { waitUntil: 'networkidle', timeout: 60000 }).catch(e => console.error('goto', e.message));
    await p.waitForTimeout(1500);
    await p.screenshot({ path: `${out}/shot-${w}.png`, fullPage: true });
    if (w === 1440) results.probe = await p.evaluate(`(${fn})()`);
    await ctx.close();
  }
  fs.writeFileSync(`${out}/probe.json`, JSON.stringify(results.probe, null, 1));
  await b.close();
})();
