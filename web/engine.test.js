import { test } from 'node:test';
import assert from 'node:assert/strict';
import { JournalEngine } from './dist/engine.js';
const tick = (engine, seconds = 30) => { for (let t=0;t<seconds;t+=.02) engine.tick(t,.02); };
test('grapheme input preserves accents, emoji and normalized newlines', () => {
  const e = new JournalEngine(); e.insert('řu\u030a👨‍👩‍👧\r\n'); assert.equal(e.glyphs.length,4); e.backspace(); e.backspace(); assert.equal(e.glyphs.map(g=>g.text).join(''),'řu\u030a');
});
test('automatic release keeps the current sentence and at least 45 characters', () => {
  const e = new JournalEngine(); e.insert('An older thought that can go now. '.repeat(10)+'This present sentence is still mine to finish and hold.'); tick(e);
  const kept = e.glyphs.slice(e.frontier).map(g=>g.text).join(''); assert.ok(kept.length>=45); assert.ok(kept.includes('This present sentence'));
});
test('long final words stay intact', () => { const e = new JournalEngine(); e.insert('hello '+ 'a'.repeat(200)); tick(e); assert.ok(e.frontier <= 6); });
test('last two words stay unaged and paused aging settles steadily', () => { const e = new JournalEngine(); e.autoRelease=false; e.insert('one two three four five six seven eight nine ten'); tick(e); assert.equal(e.glyphs.at(-1).aging,0); assert.equal(e.glyphs.at(-5).aging,0); assert.ok(e.glyphs[0].aging>.99); const age=e.glyphs[0].aging; tick(e); assert.ok(e.glyphs[0].aging>=age); });
test('backspace cannot cross aged or released text', () => { const e = new JournalEngine(); e.insert('one two three four'); tick(e); e.backspace(true); e.backspace(true); const n=e.glyphs.length; e.backspace(true); assert.ok(e.glyphs.length>=n-1); e.releaseAll(40); const released=e.glyphs.length; e.backspace(); assert.equal(e.glyphs.length,released); });
test('explicit release lets all text go and newly inserted text survives', () => { const e = new JournalEngine(); e.insert('Let everything go'); e.releaseAll(1); const end=e.frontier; e.insert('A fresh thought'); assert.equal(e.frontier,end); assert.ok(e.glyphs.slice(end).every(g=>g.releasedAt===null)); });
