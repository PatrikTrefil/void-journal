import { JournalEngine } from './engine.js';
const $ = id => document.getElementById(id);
const engine = new JournalEngine(), canvas = $('canvas'), ctx = canvas.getContext('2d'), input = $('input');
const systemDark = matchMedia('(prefers-color-scheme: dark)'), reduced = matchMedia('(prefers-reduced-motion: reduce)'), contrast = matchMedia('(forced-colors: active)');
let prefs = { theme: 'void', appearance: 'system', size: 28, motion: true, introduced: false };
try { const stored = JSON.parse(localStorage.getItem('void-preferences') || '{}'); for (const k of Object.keys(prefs)) if (typeof stored[k] === typeof prefs[k]) prefs[k] = stored[k]; } catch {}
if (!['void', 'dissolve'].includes(prefs.theme)) prefs.theme = 'void';
if (!['system', 'light', 'dark'].includes(prefs.appearance)) prefs.appearance = 'system';
if (![18, 22, 28, 34].includes(prefs.size)) prefs.size = 28;
let writing = false, intro = false, composing = false, introGeneration = 0, last = performance.now() / 1000, lastType = 0, offset = 0, width = 0, height = 0, size = prefs.size;
let dark = true;
function save() { try { localStorage.setItem('void-preferences', JSON.stringify(prefs)); } catch {} }
function apply() {
  dark = prefs.appearance === 'dark' || (prefs.appearance === 'system' && systemDark.matches);
  document.documentElement.dataset.theme = prefs.theme;
  document.documentElement.dataset.appearance = dark ? 'dark' : 'light';
  document.documentElement.style.setProperty('--font', `${prefs.size}px`);
  document.body.classList.toggle('still', !prefs.motion || reduced.matches);
  document.querySelectorAll('[data-theme]').forEach(b => { if (b.tagName === 'BUTTON') { b.classList.toggle('selected', b.dataset.theme === prefs.theme); b.setAttribute('aria-pressed', String(b.dataset.theme === prefs.theme)); } });
  $('appearance').value = prefs.appearance; $('text-size').value = prefs.size; $('motion').checked = prefs.motion;
  save();
}
apply(); systemDark.addEventListener('change', apply); reduced.addEventListener('change', apply);
document.querySelectorAll('button[data-theme]').forEach(b => b.onclick = () => { prefs.theme = b.dataset.theme; apply(); });
$('appearance').onchange = e => { prefs.appearance = e.target.value; apply(); };
$('text-size').onchange = e => { prefs.size = +e.target.value; apply(); };
$('motion').onchange = e => { prefs.motion = e.target.checked; apply(); };
function focus() { if (writing && !intro && !$('settings').open && !$('intro-end').open) input.focus({ preventScroll: true }); }
function setControls(open, returnFocus = false) {
  document.body.classList.toggle('controls-open', open);
  $('top-controls').inert = $('bottom-controls').inert = !open;
  const label = open ? 'Hide controls' : 'Show controls';
  $('controls-toggle').setAttribute('aria-expanded', String(open));
  $('controls-toggle').setAttribute('aria-label', label);
  $('controls-toggle').title = label;
  if (!open && returnFocus) { if (writing && !intro) focus(); else $('controls-toggle').focus(); }
}
$('controls-toggle').onclick = () => setControls(!document.body.classList.contains('controls-open'), true);
function start() { writing = true; document.body.classList.add('writing'); $('welcome').inert = true; setControls(false); focus(); }
$('begin').onclick = () => { if (!prefs.introduced) runIntro(); else start(); };
$('journal').addEventListener('pointerdown', e => { if (writing && !intro && e.target.tagName !== 'BUTTON') { e.preventDefault(); setControls(false); focus(); } });
$('settings-button').onclick = () => $('settings').showModal();
$('close-settings').onclick = () => $('settings').close(); $('settings').addEventListener('close', focus);
async function fullscreen() { try { if (document.fullscreenElement) await document.exitFullscreen(); else await document.documentElement.requestFullscreen(); } catch { $('intro-caption').textContent = 'Full screen is unavailable in this browser. You can still write here.'; } }
$('fullscreen').onclick = fullscreen;
document.addEventListener('fullscreenchange', () => { const label = document.fullscreenElement ? 'Exit full screen' : 'Enter full screen'; $('fullscreen').setAttribute('aria-label', label); $('fullscreen').title = label; });
if (!document.fullscreenEnabled) $('fullscreen').hidden = true;
const isMac = /Mac|iPhone|iPad/.test(navigator.platform); $('shortcut').textContent = isMac ? '⌘ ↵' : 'Ctrl ↵';
function release() { if (!intro) engine.releaseAll(performance.now() / 1000); focus(); }
$('release').onclick = release;
function typed() { setControls(false); lastType = performance.now() / 1000; document.body.classList.add('typing'); }
input.addEventListener('compositionstart', () => { composing = true; });
input.addEventListener('compositionend', e => { composing = false; if (!intro) { engine.insert(e.data); typed(); } input.value = ''; });
input.addEventListener('input', e => { if (composing || e.isComposing) return; if (intro) { input.value = ''; return; } if (input.value) { engine.insert(input.value); typed(); } input.value = ''; });
input.addEventListener('beforeinput', e => {
  if (composing || e.isComposing) return;
  if (e.inputType.startsWith('delete')) { e.preventDefault(); engine.backspace(e.inputType.includes('Word')); typed(); }
  if (['historyUndo', 'historyRedo', 'insertFromDrop'].includes(e.inputType)) e.preventDefault();
});
input.addEventListener('keydown', e => {
  if (e.isComposing) return;
  if (['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End', 'PageUp', 'PageDown', 'Delete'].includes(e.key) || ((e.metaKey || e.ctrlKey) && ['a', 'z', 'y', 'x', 'c'].includes(e.key.toLowerCase()))) e.preventDefault();
  if (e.key === 'Backspace') { e.preventDefault(); engine.backspace(e.altKey || e.ctrlKey); typed(); }
});
document.addEventListener('keydown', e => {
  if ($('settings').open || $('intro-end').open || e.isComposing) return;
  if (e.key === 'Escape' && intro) { e.preventDefault(); endIntro(); return; }
  if (e.key === 'Escape' && document.body.classList.contains('controls-open')) { e.preventDefault(); setControls(false, true); return; }
  if (e.metaKey || e.ctrlKey) {
    if (e.key === 'Enter') { e.preventDefault(); release(); }
    if (['+', '=', '-', '0'].includes(e.key)) { e.preventDefault(); const sizes = [18,22,28,34], i = sizes.indexOf(prefs.size); prefs.size = e.key === '0' ? 28 : sizes[Math.max(0, Math.min(3, i + (e.key === '-' ? -1 : 1)))]; apply(); }
  }
});
// Journal text never enters storage, network requests, logs, or DOM text nodes.
window.addEventListener('pagehide', () => { engine.reset(); input.value = ''; ctx.clearRect(0,0,width,height); });
function resize() { const box = canvas.getBoundingClientRect(), dpr = Math.min(devicePixelRatio || 1, 3); width = box.width; height = box.height; canvas.width = Math.round(width * dpr); canvas.height = Math.round(height * dpr); ctx.setTransform(dpr,0,0,dpr,0,0); }
new ResizeObserver(resize).observe(canvas);
const mix = (a,b,t) => `rgb(${a.map((v,i) => Math.round(v + (b[i]-v)*t)).join(' ')})`;
function layout() {
  size = intro ? 30 : prefs.size;
  ctx.font = `350 ${size}px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`;
  const column = Math.min(width - (width < 640 ? 48 : 96), 680 * size / 22), left = (width - column) / 2;
  const g = engine.glyphs; let x = 0, line = 0;
  for (let i = 0; i < g.length; i++) {
    if (i === 0 || g[i - 1].space) {
      let wordWidth = 0;
      for (let j = i; j < g.length && !g[j].space; j++) wordWidth += ctx.measureText(g[j].text).width;
      if (x > 0 && x + wordWidth > column) { line++; x = 0; }
    }
    const glyph = g[i], advance = glyph.text === '\n' ? 0 : ctx.measureText(glyph.text).width;
    if (x > 0 && x + advance > column && !glyph.space) { line++; x = 0; }
    glyph.x = left + x; glyph.line = line; glyph.width = advance;
    if (glyph.text === '\n') { line++; x = 0; } else x += advance;
  }
  engine.maximumKeep = Math.max(72, Math.round(column / (size * .49) * 1.5));
  return { line, x: left + x, lineHeight: size * 1.65 };
}
function render(now, dt) {
  ctx.clearRect(0,0,width,height);
  const {line, x, lineHeight} = layout(), g = engine.glyphs;
  const target = Math.max(0, line - Math.max(0, Math.floor(height * .32 / lineHeight)));
  offset += (target - offset) * (reduced.matches ? 1 : 1-Math.exp(-dt/.5));
  const base = height * .45;
  let fg = dark ? [237,230,250] : [51,36,72], tint = dark ? [150,104,235] : [144,107,205];
  if (prefs.theme === 'dissolve') { fg = dark ? [231,231,234] : [48,48,45]; tint = fg; }
  if (contrast.matches) { fg = dark ? [255,255,255] : [0,0,0]; tint = fg; }
  for (const glyph of g) {
    const elapsed = glyph.releasedAt === null ? 0 : Math.max(0,now-glyph.releasedAt), t = Math.min(1,elapsed / engine.fadeDuration), eased = t*t*(3-2*t);
    const age = Math.pow(glyph.aging,1.4), y = base + (glyph.line-offset)*lineHeight;
    if (t >= 1 || glyph.space || y < -lineHeight || y > height+lineHeight) continue;
    ctx.globalAlpha = (contrast.matches ? 1 : 1-.65*age)*(1-eased);
    ctx.fillStyle = mix(fg,tint,prefs.theme === 'void' ? Math.min(1,age*.7+eased*.3) : 0);
    const lift = reduced.matches ? 0 : prefs.theme === 'void' ? eased*18 : eased*7;
    if (prefs.theme === 'void' && t > 0 && !reduced.matches) ctx.filter = `blur(${eased*5}px)`;
    ctx.fillText(glyph.text,glyph.x,y-lift); ctx.filter = 'none';
    if (prefs.theme === 'dissolve' && !reduced.matches && !contrast.matches) {
      const strength = Math.max(age*.2,eased*(1-eased)*4);
      for (let k=0;k<4;k++) {
        const phase = ((now*.24+glyph.id*.173+k*.231)%1), seed = Math.sin(glyph.id*12.9+k*7.3)*.5+.5;
        ctx.globalAlpha = strength*(1-phase)*.38;
        ctx.fillRect(glyph.x+seed*glyph.width+Math.sin(phase*5+seed)*9, y-size*.5-phase*(22+seed*25),1.1,1.1);
      }
    }
  }
  ctx.globalAlpha = 1;
  if (writing && !intro && document.activeElement === input && (now-lastType < 1 || Math.sin(now*3)>-.15)) {
    ctx.fillStyle = mix(fg,tint,.5); ctx.fillRect(x,base+(line-offset)*lineHeight-size*.8,1.4,size);
  }
  // Only remove complete, fully faded lines, keeping surviving line wraps stable.
  let trim = 0;
  for (let i = 0; i < g.length; ) {
    const lineNumber = g[i].line; let end = i;
    while (end < g.length && g[end].line === lineNumber) end++;
    if (end < g.length && g.slice(i,end).every(a => a.releasedAt !== null && now-a.releasedAt > engine.fadeDuration)) { trim = end; i = end; } else break;
  }
  if (g.length && g.every(a => a.releasedAt !== null && now-a.releasedAt > engine.fadeDuration)) { engine.reset(); offset = 0; }
  else if (trim) { const removed = g[trim].line; engine.trim(trim); offset -= removed; }
  document.body.classList.toggle('empty',g.length === 0);
  $('release').disabled = engine.frontier >= g.length;
}
function frame(ms) { const now = ms/1000, dt = Math.min(.1,now-last); last = now; engine.tick(now,dt); render(now,dt); if (now-lastType>1.8) document.body.classList.remove('typing'); requestAnimationFrame(frame); }
requestAnimationFrame(frame);
const pause = ms => new Promise(resolve => setTimeout(resolve,ms));
async function runIntro() {
  $('settings').close(); start(); intro = true; document.body.classList.add('intro'); engine.reset(); offset = 0; engine.autoRelease = false;
  const generation = ++introGeneration;
  $('intro-caption').textContent = 'A space to let your thoughts pass through. · Esc to skip';
  for (const sentence of ['You don’t have to hold on to every thought.', 'Let the words come. Then let them go.']) {
    for (const {segment} of new Intl.Segmenter(undefined,{granularity:'grapheme'}).segment(sentence)) { if (generation !== introGeneration) return; engine.insert(segment); await pause(reduced.matches ? 16 : 65); }
    await pause(1200); if (generation !== introGeneration) return;
    engine.releaseAll(performance.now()/1000); await pause(3800); if (generation !== introGeneration) return;
  }
  endIntro();
}
function endIntro() { introGeneration++; intro = false; engine.reset(); offset = 0; engine.autoRelease = true; document.body.classList.remove('intro'); $('intro-caption').textContent = ''; prefs.introduced = true; save(); $('intro-end').showModal(); }
$('show-intro').onclick = runIntro; $('replay').onclick = runIntro;
function finishIntro() { $('intro-end').close(); start(); }
$('intro-skip').onclick = finishIntro;
$('intro-fullscreen').onclick = async () => { await fullscreen(); finishIntro(); };
$('intro-end').addEventListener('close', focus);
