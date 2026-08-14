/*
 * Regenerates the raster assets in static/ from the mark in static/icon.svg.
 *
 *   node build-assets.js
 *
 * This is a ONE-OFF tool, not part of the normal build. The outputs are committed,
 * because they change roughly never and adding a node_modules to this repo just to
 * redraw an icon is a bad trade. build.ps1 stays dependency-free and simply links
 * to whatever is sitting in static/.
 *
 * It needs puppeteer-core and a Chrome on disk. Neither is a dependency of this
 * repo; point NODE_PATH at any node_modules that has puppeteer-core, e.g.
 *
 *   NODE_PATH=/path/to/some/node_modules node build-assets.js
 *
 * Why raster at all, when the favicon is an SVG? Two reasons, both about places
 * that refuse SVG:
 *   - Android home-screen and iOS apple-touch-icon want PNGs at fixed sizes.
 *   - Share-card crawlers (WhatsApp, LinkedIn, Slack, iMessage) will not read an
 *     SVG and will not read a data: URI. og:image has to be a real PNG at a real
 *     absolute URL, which is why static/ has to be uploaded as files.
 */

const fs = require('fs');
const path = require('path');
const puppeteer = require('puppeteer-core');

const CHROME = process.env.CHROME || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const OUT = path.join(__dirname, 'static');

// ── the mark ──────────────────────────────────────────────────────────────────
// Three crossing bars through the centre of a 64-unit box. Kept here as geometry
// rather than as a copy of the SVG file so the maskable and full-bleed variants
// can reuse it at different scales.

const BLUE = '#1F5FA8';
const LIGHT = '#EDF0F4';

// r is the arm length from centre. Keep r/stroke around 2.5-3: much below that and
// the three bars merge into a blob, much above and the arms vanish at favicon size.
// The leading + matters - toFixed returns a string, and `32 + "16.45"` concatenates.
function asterisk(stroke, colour, r) {
  const dx = +(r * Math.cos(Math.PI / 6)).toFixed(2);
  const dy = +(r * Math.sin(Math.PI / 6)).toFixed(2);
  return `
  <g stroke="${colour}" stroke-width="${stroke}" stroke-linecap="round">
    <line x1="32" y1="${32 - r}" x2="32" y2="${32 + r}"/>
    <line x1="${32 - dx}" y1="${32 - dy}" x2="${32 + dx}" y2="${32 + dy}"/>
    <line x1="${32 - dx}" y1="${32 + dy}" x2="${32 + dx}" y2="${32 - dy}"/>
  </g>`;
}

// rx 13 matches static/icon.svg. Full-bleed (rx 0) is for surfaces that apply
// their own mask - iOS rounds apple-touch-icon itself, and rounding it twice
// leaves a pale seam in the corners.
const rounded = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="13" fill="${BLUE}"/>${asterisk(7, LIGHT, 19)}</svg>`;
const fullBleed = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" fill="${BLUE}"/>${asterisk(7, LIGHT, 19)}</svg>`;
// Android masks maskable icons to a circle and can crop up to 20% off each edge,
// so the mark shrinks to sit inside the safe zone: arm plus cap must stay within
// 25.6 units of centre.
const maskable = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" fill="${BLUE}"/>${asterisk(6, LIGHT, 16)}</svg>`;

const ICONS = [
  { file: 'icon-32.png', size: 32, svg: rounded },
  { file: 'icon-192.png', size: 192, svg: rounded },
  { file: 'icon-512.png', size: 512, svg: rounded },
  { file: 'icon-maskable-512.png', size: 512, svg: maskable },
  { file: 'apple-touch-icon.png', size: 180, svg: fullBleed },
];

// ── the share card ────────────────────────────────────────────────────────────
// Dark, because a share card is seen inside someone else's white chat window and
// a light card dissolves into it. 1200x630 is the size every crawler expects.

const MONO = `ui-monospace, "Cascadia Mono", "SF Mono", Consolas, monospace`;

const card = `
<div id="card">
  <div class="top">
    <svg class="mark" viewBox="0 0 64 64"><rect width="64" height="64" rx="13" fill="#74ACE0"/>${asterisk(7, '#11151B', 19)}</svg>
    <div class="who">
      <div class="name">devin jones</div>
      <div class="place">london</div>
    </div>
  </div>

  <div class="rule"></div>

  <div class="lines">
    <div class="line">
      <span class="expr blue">0 9 * * 1-5</span>
      <span class="gloss">the job &mdash; monday to friday, at 09:00</span>
    </div>
    <div class="line">
      <span class="expr amber">0 11 * * 6,0</span>
      <span class="gloss">the habit &mdash; saturday and sunday, at 11:00</span>
    </div>
  </div>

  <div class="url">devinjones.co.uk</div>
</div>

<style>
  * { box-sizing: border-box; margin: 0; }
  html, body { width: 1200px; height: 630px; }
  body {
    background: #11151B; color: #DEE6F0;
    font-family: ${MONO};
    -webkit-font-smoothing: antialiased;
  }
  #card { width: 1200px; height: 630px; padding: 76px 92px 66px; display: flex; flex-direction: column; }
  .top { display: flex; align-items: center; gap: 34px; }
  .mark { width: 104px; height: 104px; flex: none; }
  .name { font-size: 76px; font-weight: 600; letter-spacing: -.03em; line-height: 1; }
  .place { font-size: 28px; color: #616E7D; margin-top: 14px; }
  .rule { height: 1px; background: #232B35; margin-top: 62px; }
  .lines { padding-top: 50px; display: flex; flex-direction: column; gap: 30px; }
  .line { display: flex; align-items: baseline; gap: 30px; }
  .expr { font-size: 34px; font-weight: 600; letter-spacing: .02em; width: 260px; flex: none; }
  .blue { color: #74ACE0; }
  .amber { color: #DBA260; }
  .gloss { font-size: 27px; color: #8E9BAC; }
  /* Pushed to the baseline of the card, so the block of type reads top-down and
     the empty space lands in one place instead of as a hole in the middle. */
  .url { margin-top: auto; font-size: 25px; color: #616E7D; letter-spacing: .02em; }
</style>`;

// ── render ────────────────────────────────────────────────────────────────────

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new' });
  const page = await browser.newPage();

  for (const icon of ICONS) {
    await page.setViewport({ width: icon.size, height: icon.size, deviceScaleFactor: 1 });
    await page.setContent(
      `<style>html,body{margin:0;padding:0;background:transparent}svg{display:block;width:${icon.size}px;height:${icon.size}px}</style>${icon.svg}`
    );
    await page.screenshot({ path: path.join(OUT, icon.file), omitBackground: true });
    console.log('wrote static/' + icon.file);
  }

  await page.setViewport({ width: 1200, height: 630, deviceScaleFactor: 1 });
  await page.setContent(card);
  await page.evaluateHandle('document.fonts.ready');
  await page.screenshot({ path: path.join(OUT, 'og.png') });
  console.log('wrote static/og.png');

  await browser.close();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
