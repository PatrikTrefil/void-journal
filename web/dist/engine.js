const segmenter = new Intl.Segmenter(undefined, { granularity: 'grapheme' });
export class JournalEngine {
  glyphs = []; frontier = 0; rate = 0; budget = 0; nextId = 0;
  maximumKeep = 100; autoRelease = true; fadeDuration = 2.8;
  insert(text) {
    const parts = [...segmenter.segment(text.replace(/\r\n?/g, '\n').replace(/\t/g, ' '))];
    for (const { segment: text } of parts) this.glyphs.push({ text, id: this.nextId++, space: /^\s+$/u.test(text), aging: 0, releasedAt: null });
    this.rate += Math.min(parts.length, 3) / 2;
  }
  backspace(word = false) {
    const removable = () => this.glyphs.length > this.frontier && this.glyphs.at(-1).aging < .015;
    if (!word) { if (removable()) this.glyphs.pop(); return; }
    while (removable() && this.glyphs.at(-1).space) this.glyphs.pop();
    while (removable() && !this.glyphs.at(-1).space) this.glyphs.pop();
  }
  releaseAll(now) {
    for (let i = this.frontier; i < this.glyphs.length; i++) {
      this.glyphs[i].releasedAt = now;
      if (!this.glyphs[i].space) now += .012;
    }
    this.frontier = this.glyphs.length;
  }
  target() {
    const g = this.glyphs, n = g.length, max = Math.max(72, this.maximumKeep);
    if (!this.autoRelease || n <= 45) return this.frontier;
    let start = Math.max(0, n - max);
    for (let i = n - 1; i > 0 && i >= n - max; i--) {
      if (g[i].text === '\n' || (g[i].space && /[.!?…]/u.test(g[i - 1].text))) { start = i + 1; break; }
    }
    let keep = Math.min(start, n - 45);
    while (keep > 0 && !g[keep - 1].space) keep--;
    if (n - keep > max) {
      let candidate = n - max;
      while (candidate < n && !g[candidate - 1].space) candidate++;
      if (candidate <= n - 45) keep = candidate;
    }
    return Math.max(this.frontier, keep);
  }
  tick(now, dt) {
    dt = Math.min(.1, Math.max(0, dt));
    this.rate *= Math.exp(-dt / 2);
    const target = this.target();
    if (target > this.frontier) {
      this.budget = Math.min(8, this.budget + Math.max(3, this.rate * 1.1, (target - this.frontier) * .5) * dt);
      while (this.frontier < target) {
        if (!this.glyphs[this.frontier].space) { if (this.budget < 1) break; this.budget--; }
        this.glyphs[this.frontier++].releasedAt = now;
      }
    } else this.budget = Math.min(this.budget, 1);
    let words = 0;
    for (let i = this.glyphs.length - 1; i >= 0; i--) {
      const g = this.glyphs[i];
      if (g.space && i + 1 < this.glyphs.length && !this.glyphs[i + 1].space) words++;
      let age = Math.max(0, Math.min(1, (words - 1) / 6));
      if (g.releasedAt !== null) age = Math.max(age, g.aging);
      g.aging += (age - g.aging) * (1 - Math.exp(-dt / .9));
    }
  }
  trim(count) { count = Math.min(count, this.frontier); this.glyphs.splice(0, count); this.frontier -= count; }
  reset() { this.glyphs.length = 0; this.frontier = 0; this.rate = this.budget = 0; }
}
