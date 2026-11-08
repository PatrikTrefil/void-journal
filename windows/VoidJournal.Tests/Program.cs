using VoidJournal.Core;

static void Check(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
}

var engine = new JournalEngine();
engine.Insert("řů e\u0301 👩‍💻");
Check(engine.Glyphs.Count == 6, "Input must preserve extended grapheme clusters.");
engine.Backspace();
Check(engine.Glyphs[^1].Text == " ", "Backspace must remove a whole emoji.");
engine.Reset();
engine.Insert("Keep this sentence.");
for (int i = 0; i < 1000; i++) engine.Tick(i * .05, .05);
Check(engine.Frontier == 0, "Short thoughts must remain visible indefinitely.");
engine.Reset();
engine.Insert(string.Concat(Enumerable.Repeat("Older thoughts can drift away. ", 20)) + "My newest thought stays here, visible as I pause.");
for (int i = 0; i < 1000; i++) engine.Tick(i * .05, .05);
Check(engine.Frontier > 0, "Long text should release automatically.");
Check(engine.Glyphs.Count - engine.Frontier >= 45, "Automatic release must retain recent text.");
Check(engine.Glyphs[^1].Aging == 0 && engine.Glyphs[^5].Aging == 0, "The newest two words must not age.");
int retained = engine.Glyphs.Count - engine.Frontier;
for (int i = 0; i < retained + 10; i++) engine.Backspace();
Check(engine.Glyphs.Count == engine.Frontier, "Backspace must stop at released text.");
engine.Reset();
engine.Insert("Let everything go, including this sentence.");
engine.ReleaseAll(1);
Check(engine.Frontier == engine.Glyphs.Count, "Explicit release must include the current sentence.");
engine.Backspace();
Check(engine.Glyphs.Count == engine.Frontier, "Explicitly released text cannot be edited.");
Check(engine.Glyphs.All(g => engine.Finished(g, 10)), "Released glyphs must finish animating.");
engine.Trim(engine.Glyphs.Count);
Check(engine.Glyphs.Count == 0 && engine.Frontier == 0, "Finished writing must be discarded.");
engine.Insert("Another thought");
engine.Backspace(true);
Check(string.Concat(engine.Glyphs.Select(g => g.Text)) == "Another ", "Control Backspace should delete one word.");
engine.AutoRelease = false;
engine.Insert(new string('x', 500));
engine.Tick(20, .1);
Check(engine.Frontier == 0, "The introduction must control release manually.");
engine.Reset();
engine.AutoRelease = true;
engine.Insert("An older sentence. " + new string('x', 300));
for (int i = 0; i < 1000; i++) engine.Tick(i * .05, .05);
Check(engine.Glyphs.Count - engine.Frontier >= 300, "Automatic release must never consume an unbroken final word.");
Console.WriteLine("All journal engine checks passed.");
