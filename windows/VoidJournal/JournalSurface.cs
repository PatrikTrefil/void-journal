using System.Globalization;
using System.Windows;
using System.Windows.Media;
using Microsoft.Win32;
using VoidJournal.Core;

namespace VoidJournal;

public sealed class JournalSurface : FrameworkElement
{
    public JournalEngine Engine { get; } = new();
    public Preferences Preferences { get; set; } = new();
    public double Now { get; set; }
    public double FrameDelta { get; set; } = 1 / 60.0;
    public Point Caret { get; private set; }
    public FontFamily JournalFont => new(Preferences.Typeface switch
    {
        "Sans Serif" => "Segoe UI Variable",
        "Monospaced" => "Cascadia Mono, Consolas",
        _ => "Georgia"
    });
    private sealed record GlyphDrawing(double Advance, Geometry Outline);
    private readonly Dictionary<string, GlyphDrawing> textCache = [];
    private readonly Dictionary<Color, SolidColorBrush> brushes = [];
    private readonly List<Point> positions = [];
    private RadialGradientBrush? voidGradient;
    private bool gradientDark;
    private double displayLine;
    private int droppedLines;
    private bool systemDark;
    private double lastAppearanceCheck = -10;

    public void ClearTextCache() { textCache.Clear(); brushes.Clear(); }

    protected override void OnDpiChanged(DpiScale oldDpi, DpiScale newDpi)
    {
        base.OnDpiChanged(oldDpi, newDpi);
        ClearTextCache();
        InvalidateVisual();
    }

    protected override void OnRender(DrawingContext dc)
    {
        base.OnRender(dc);
        if (ActualWidth <= 0 || ActualHeight <= 0) return;
        bool highContrast = SystemParameters.HighContrast;
        bool reduceMotion = !SystemParameters.ClientAreaAnimation;
        if (Now - lastAppearanceCheck > 2)
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            systemDark = key?.GetValue("AppsUseLightTheme") is int value && value == 0;
            lastAppearanceCheck = Now;
        }
        bool dark = Preferences.Appearance == "Dark" || (Preferences.Appearance == "System" && systemDark);
        bool violet = Preferences.Theme == "Void";
        Color foreground = highContrast ? SystemColors.WindowTextColor : dark ? Color.FromRgb(239, 234, 248) : Color.FromRgb(44, 34, 58);
        Color background = highContrast ? SystemColors.WindowColor : violet
            ? dark ? Color.FromRgb(20, 14, 38) : Color.FromRgb(244, 237, 255)
            : dark ? Color.FromRgb(22, 24, 28) : Color.FromRgb(248, 246, 241);
        dc.DrawRectangle(BrushFor(background), null, new Rect(RenderSize));
        if (violet && !highContrast)
        {
            double phase = Preferences.MovingGradients && !reduceMotion ? Now * .08 : 0;
            if (voidGradient == null || gradientDark != dark)
            {
                voidGradient = new RadialGradientBrush
                {
                    GradientOrigin = new Point(.5, .5), Center = new Point(.5, .5), RadiusX = .5, RadiusY = .5,
                    GradientStops = new GradientStopCollection
                    {
                        new(Color.FromArgb(dark ? (byte)78 : (byte)48, 132, 72, 208), 0),
                        new(Colors.Transparent, 1)
                    }
                };
                voidGradient.Freeze();
                gradientDark = dark;
            }
            dc.DrawEllipse(voidGradient, null, new Point(ActualWidth * (.5 + .15 * Math.Sin(phase)), ActualHeight * .4), ActualWidth * .7, ActualHeight * .8);
        }

        double size = Preferences.TextSize, lineHeight = size * 1.65;
        double width = Math.Max(120, Math.Min(ActualWidth - 96, 680 * size / 22));
        Engine.MaximumKeep = Math.Max(72, (int)(width * 1.5 / (size * .52)));
        positions.Clear();
        double x = 0;
        int line = 0, lastBreak = -1;
        for (int i = 0; i < Engine.Glyphs.Count; i++)
        {
            var glyph = Engine.Glyphs[i];
            double advance = Measure(glyph.Text).Advance;
            if (glyph.Text == "\n")
            {
                positions.Add(new Point(x, line));
                x = 0; line++; lastBreak = -1;
                continue;
            }
            if (!glyph.IsBreak && x + advance > width && x > 0)
            {
                line++; x = 0;
                if (lastBreak >= 0)
                    for (int j = lastBreak + 1; j < i; j++)
                    {
                        positions[j] = new Point(x, line);
                        x += Measure(Engine.Glyphs[j].Text).Advance;
                    }
                lastBreak = -1;
            }
            positions.Add(new Point(x, line));
            x += advance;
            if (glyph.IsBreak) lastBreak = i;
        }
        double target = droppedLines + line;
        displayLine = reduceMotion ? target : displayLine + (target - displayLine) * (1 - Math.Exp(-Math.Clamp(FrameDelta, 0, .1) * 9));
        double left = (ActualWidth - width) / 2;
        double top = ActualHeight * .48 - (displayLine - droppedLines) * lineHeight;
        Caret = new Point(left + x, top + line * lineHeight);
        dc.PushClip(new RectangleGeometry(new Rect(RenderSize)));
        StreamGeometry[] particles = new StreamGeometry[4];
        StreamGeometryContext[] particleContexts = new StreamGeometryContext[4];
        bool drawParticles = !violet && !reduceMotion && !highContrast;
        if (drawParticles)
            for (int bucket = 0; bucket < particles.Length; bucket++)
            {
                particles[bucket] = new StreamGeometry();
                particleContexts[bucket] = particles[bucket].Open();
            }
        for (int i = 0; i < Engine.Glyphs.Count; i++)
        {
            var glyph = Engine.Glyphs[i];
            if (glyph.IsBreak) continue;
            double progress = glyph.ReleasedAt is double at ? Math.Clamp((Now - at) / Engine.FadeDuration, 0, 1) : 0;
            if (progress >= 1) continue;
            double aging = Math.Pow(glyph.Aging, 1.4);
            double opacity = (1 - .65 * aging) * Math.Pow(1 - progress, 1.5);
            Point origin = new(left + positions[i].X, top + positions[i].Y * lineHeight - (reduceMotion ? 0 : progress * size * .7));
            if (origin.Y < -lineHeight || origin.Y > ActualHeight + lineHeight) continue;
            double tint = Math.Round((aging * .65 + progress * .35) * 64) / 64;
            Color ink = violet && !highContrast ? Blend(foreground, dark ? Color.FromRgb(175, 130, 240) : Color.FromRgb(126, 78, 180), tint) : foreground;
            var text = Measure(glyph.Text);
            var transform = new TranslateTransform(origin.X, origin.Y);
            transform.Freeze();
            dc.PushTransform(transform);
            dc.PushOpacity(highContrast && progress == 0 ? 1 : opacity);
            if (!violet && !reduceMotion && progress > 0)
            {
                // A left-to-right clipping sweep exposes drifting pieces of each glyph.
                double remaining = text.Advance * (1 - progress);
                dc.PushClip(new RectangleGeometry(new Rect(text.Advance - remaining, 0, remaining + 1, lineHeight)));
                dc.DrawGeometry(BrushFor(ink), null, text.Outline);
                dc.Pop();
            }
            else dc.DrawGeometry(BrushFor(ink), null, text.Outline);
            dc.Pop();
            dc.Pop();
            if (drawParticles)
            {
                int count = progress > 0 ? 12 : (int)(aging * 4);
                for (int p = 0; p < count; p++)
                {
                    double seed = (glyph.Id * 17 + p * 37) % 101 / 101.0;
                    double travel = progress > 0 ? progress : (Now * .35 + seed) % 1;
                    double alpha = (progress > 0 ? 1 : aging * .35) * (1 - travel) * .55;
                    int bucket = Math.Clamp((int)(alpha / .55 * 4), 0, 3);
                    if (alpha < .025) continue;
                    double px = origin.X + seed * text.Advance + Math.Sin(seed * 20) * travel * 25;
                    double py = origin.Y + size * (.2 + seed * .7) - travel * 42;
                    // Batch diamond-shaped specks into four opacity bands, rather than
                    // allocating a separate WPF brush and draw command for every particle.
                    var context = particleContexts[bucket];
                    context.BeginFigure(new Point(px, py - 1.1), true, true);
                    context.LineTo(new Point(px + 1.1, py), false, false);
                    context.LineTo(new Point(px, py + 1.1), false, false);
                    context.LineTo(new Point(px - 1.1, py), false, false);
                }
            }
        }
        if (drawParticles)
            for (int bucket = 0; bucket < particles.Length; bucket++)
            {
                particleContexts[bucket].Close();
                particles[bucket].Freeze();
                dc.PushOpacity((bucket + .5) / 4 * .55);
                dc.DrawGeometry(BrushFor(foreground), null, particles[bucket]);
                dc.Pop();
            }
        if (Engine.AutoRelease && (Now % 1.2 < .75))
            dc.DrawLine(new Pen(BrushFor(foreground), 1.3), Caret, new Point(Caret.X, Caret.Y + size * 1.2));
        if (Engine.Glyphs.Count == 0 && Engine.AutoRelease)
        {
            var hint = Measure("Write it down. Let it go.");
            dc.PushOpacity(.35);
            dc.PushTransform(new TranslateTransform(left, top));
            dc.DrawGeometry(BrushFor(foreground), null, hint.Outline);
            dc.Pop();
            dc.Pop();
        }
        dc.Pop();

        int trim = 0;
        if (Engine.Glyphs.Count > 0 && Engine.Glyphs.All(g => Engine.Finished(g, Now)))
        {
            trim = Engine.Glyphs.Count;
            droppedLines += line + 1;
        }
        else
        {
            for (int i = 0; i < positions.Count && positions[i].Y < line;)
            {
                int end = i;
                while (end < positions.Count && positions[end].Y == positions[i].Y) end++;
                bool finished = true;
                for (int j = i; j < end; j++)
                    if (!Engine.Finished(Engine.Glyphs[j], Now)) { finished = false; break; }
                if (!finished) break;
                trim = end;
                droppedLines++;
                i = end;
            }
        }
        if (trim > 0) Engine.Trim(trim);
        // Avoid retaining every grapheme ever typed in long-running sessions.
        if (textCache.Count > 2048) ClearTextCache();
    }

    private GlyphDrawing Measure(string text)
    {
        if (!textCache.TryGetValue(text, out var formatted))
        {
            var layout = new FormattedText(text == "\n" ? " " : text, CultureInfo.CurrentUICulture, FlowDirection.LeftToRight, new Typeface(JournalFont, FontStyles.Normal, FontWeights.Normal, FontStretches.Normal), Preferences.TextSize, Brushes.White, VisualTreeHelper.GetDpi(this).PixelsPerDip);
            var outline = layout.BuildGeometry(new Point());
            outline.Freeze();
            formatted = new GlyphDrawing(layout.WidthIncludingTrailingWhitespace, outline);
            textCache[text] = formatted;
        }
        return formatted;
    }

    private SolidColorBrush BrushFor(Color color)
    {
        if (!brushes.TryGetValue(color, out var brush))
        {
            brush = new SolidColorBrush(color);
            brush.Freeze();
            brushes[color] = brush;
        }
        return brush;
    }

    private static Color Blend(Color a, Color b, double t) => Color.FromRgb((byte)(a.R + (b.R - a.R) * t), (byte)(a.G + (b.G - a.G) * t), (byte)(a.B + (b.B - a.B) * t));
}
