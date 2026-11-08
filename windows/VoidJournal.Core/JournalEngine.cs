using System.Globalization;

namespace VoidJournal.Core;

public sealed class Glyph(string text, int id)
{
    public string Text { get; } = text;
    public int Id { get; } = id;
    public bool IsBreak => string.IsNullOrWhiteSpace(Text);
    public double Aging { get; set; }
    public double? ReleasedAt { get; set; }
}

// No file access: writing exists only in this object, never in preferences or logs.
public sealed class JournalEngine
{
    public List<Glyph> Glyphs { get; } = [];
    public int Frontier { get; private set; }
    public bool AutoRelease { get; set; } = true;
    public int MaximumKeep { get; set; } = 100;
    public double FadeDuration { get; set; } = 2.8;
    private int nextId;
    private double rate, budget;

    public void Insert(string text)
    {
        var elements = StringInfo.GetTextElementEnumerator(text.Replace("\r\n", "\n").Replace('\r', '\n').Replace('\t', ' '));
        int count = 0;
        while (elements.MoveNext())
        {
            Glyphs.Add(new Glyph(elements.GetTextElement(), nextId++));
            count++;
        }
        rate += Math.Min(count, 3) / 2.0;
    }

    public void Backspace(bool word = false)
    {
        if (!word)
        {
            if (Glyphs.Count > Frontier) Glyphs.RemoveAt(Glyphs.Count - 1);
            return;
        }
        while (Glyphs.Count > Frontier && Glyphs[^1].IsBreak) Glyphs.RemoveAt(Glyphs.Count - 1);
        while (Glyphs.Count > Frontier && !Glyphs[^1].IsBreak) Glyphs.RemoveAt(Glyphs.Count - 1);
    }

    public void ReleaseAll(double now)
    {
        double start = now;
        for (int i = Frontier; i < Glyphs.Count; i++)
        {
            Glyphs[i].ReleasedAt = start;
            if (!Glyphs[i].IsBreak) start += .012;
        }
        Frontier = Glyphs.Count;
    }

    public void Reset() { Glyphs.Clear(); Frontier = 0; budget = 0; rate = 0; }

    private int Target()
    {
        if (!AutoRelease || Glyphs.Count <= 45) return Frontier;
        int count = Glyphs.Count, max = Math.Max(72, MaximumKeep);
        int start = Math.Max(0, count - max);
        for (int i = count - 1; i > 0 && i >= count - max; i--)
        {
            if (Glyphs[i].Text == "\n" || (Glyphs[i].IsBreak && ".!?…".Contains(Glyphs[i - 1].Text, StringComparison.Ordinal)))
            { start = i + 1; break; }
        }
        int keep = Math.Min(start, count - 45);
        while (keep > 0 && !Glyphs[keep - 1].IsBreak) keep--;
        if (count - keep > max)
        {
            int candidate = count - max;
            while (candidate < count && !Glyphs[candidate - 1].IsBreak) candidate++;
            // A very long final word must stay intact, even beyond the usual retention window.
            if (candidate <= count - 45) keep = candidate;
        }
        return Math.Max(Frontier, keep);
    }

    public void Tick(double now, double dt)
    {
        dt = Math.Clamp(dt, 0, .1);
        rate *= Math.Exp(-dt / 2);
        int target = Target();
        if (target > Frontier)
        {
            budget = Math.Min(8, budget + Math.Max(3, Math.Max(rate * 1.1, (target - Frontier) * .5)) * dt);
            while (Frontier < target)
            {
                if (!Glyphs[Frontier].IsBreak)
                {
                    if (budget < 1) break;
                    budget--;
                }
                Glyphs[Frontier++].ReleasedAt = now;
            }
        }
        else budget = Math.Min(budget, 1);
        int words = 0;
        for (int i = Glyphs.Count - 1; i >= 0; i--)
        {
            if (Glyphs[i].IsBreak && i + 1 < Glyphs.Count && !Glyphs[i + 1].IsBreak) words++;
            double aging = Math.Clamp((words - 1) / 6.0, 0, 1);
            if (Glyphs[i].ReleasedAt != null) aging = Math.Max(aging, Glyphs[i].Aging);
            Glyphs[i].Aging += (aging - Glyphs[i].Aging) * (1 - Math.Exp(-dt / .9));
        }
        // Drop only complete lines in the renderer; it calls Trim after layout.
    }

    public bool Finished(Glyph glyph, double now) => glyph.ReleasedAt is double at && now - at > FadeDuration;
    public void Trim(int count)
    {
        count = Math.Min(count, Frontier);
        Glyphs.RemoveRange(0, count);
        Frontier -= count;
    }
}
