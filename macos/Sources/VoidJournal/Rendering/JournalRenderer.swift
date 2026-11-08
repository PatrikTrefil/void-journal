import SwiftUI

struct RenderStyle {
    var theme: Theme
    var isDark: Bool
    var reduceMotion: Bool
    /// Vertical position of the writing line, as a fraction of the height.
    var verticalAnchor: CGFloat = 0.45
    var maxColumnWidth: CGFloat = 680
    var placeholder: String?
}

/// Draws a `JournalEngine` into a SwiftUI `Canvas`.
enum JournalRenderer {
    private static let bucketCount = 4

    static func draw(
        engine: JournalEngine, in context: inout GraphicsContext,
        size: CGSize, now: Double, style: RenderStyle
    ) {
        let margin = max(40, size.width * 0.08)
        let column = max(200, min(style.maxColumnWidth, size.width - margin * 2))
        engine.setColumnWidth(column)
        engine.fadeDuration = style.theme.fadeDuration
        engine.tick(now: now)

        let palette = Palette(theme: style.theme, isDark: style.isDark)
        let cache = engine.glyphCache
        let originX = ((size.width - column) / 2).rounded()
        let anchorY = (size.height * style.verticalAnchor).rounded()
        let lineHeight = engine.lineHeight
        let topFade = max(size.height * 0.18, lineHeight * 2)

        func baseline(_ line: Int) -> CGFloat {
            anchorY + CGFloat(Double(line + engine.droppedLines) - engine.displayLine) * lineHeight
        }

        var buckets = Array(repeating: Path(), count: bucketCount)

        for glyph in engine.glyphs where !glyph.isBreak {
            let x = originX + glyph.x
            let y = baseline(glyph.line)
            guard y > -lineHeight, y < size.height + lineHeight else { continue }
            // Words that scroll toward the top edge soften instead of being cut off.
            let edge = Double(min(1, max(0, (y - cache.ascent) / topFade)))
            let progress = glyph.releasedAt.map { (now - $0) / engine.fadeDuration } ?? -1
            if progress >= 1 || edge <= 0 { continue }
            // Curved so the oldest words carry most of the effect.
            let age = pow(glyph.aging, 1.4)

            if style.reduceMotion {
                let opacity = (1 - agedFade * age) * (1 - smoothstep(0, 1, max(0, progress))) * edge
                drawGlyph(glyph.shape, x: x, y: y, color: palette.text, opacity: opacity, cache: cache, in: &context)
                continue
            }
            switch style.theme {
            case .dissolve:
                if progress <= 0 {
                    drawGlyph(
                        glyph.shape, x: x, y: y, color: palette.text, opacity: (1 - agedFade * age) * edge,
                        cache: cache, in: &context)
                    shed(glyph, x: x, y: y, age: age, edge: edge, now: now, buckets: &buckets)
                } else {
                    dissolve(
                        glyph, x: x, y: y, progress: progress, age: age, edge: edge,
                        palette: palette, cache: cache, buckets: &buckets, in: &context)
                }
            case .void:
                fadeIntoVoid(
                    glyph, x: x, y: y, progress: max(0, progress), age: age, edge: edge, now: now,
                    palette: palette, cache: cache, in: &context)
            }
        }

        for (index, bucket) in buckets.enumerated() where !bucket.isEmpty {
            let opacity = (Double(index) + 0.65) / Double(bucketCount)
            context.fill(bucket, with: .color(palette.text.color(opacity * 0.9)))
        }

        drawCaretAndComposition(
            engine: engine, originX: originX, baseline: baseline(engine.caretLine),
            now: now, palette: palette, style: style, in: &context)
    }

    // MARK: - Glyphs

    /// How much of the opacity kept text loses while it waits to be released.
    private static let agedFade = 0.65

    /// A few particles that slowly drift off kept letters on a loop, like wisps of smoke.
    private static func shed(
        _ glyph: Glyph, x: CGFloat, y: CGFloat, age: Double, edge: Double, now: Double,
        buckets: inout [Path]
    ) {
        guard age > 0.01 else { return }
        var rng = SplitMix64(seed: UInt64(glyph.id) &* 0x9E37_79B9 &+ 17)
        let samples = glyph.shape.samples
        for index in stride(from: 0, to: samples.count, by: 3) {
            let sample = samples[index]
            let r1 = Double(rng.unit())
            let r2 = Double(rng.unit())
            let r3 = Double(rng.unit())
            let r4 = Double(rng.unit())
            let period = 2.8 + r1 * 2.2
            let cycle = (now - glyph.bornAt) / period + r2
            let t = cycle - floor(cycle)
            let px = x + sample.x + CGFloat((r3 * 1.4 - 0.4) * 9 * t + sin(t * 4 + r4 * 6.283) * 1.2)
            let py = y + sample.y - CGFloat((5 + r4 * 12) * t)
            let opacity = min(1, sin(.pi * t) * 1.3 * age) * edge
            guard opacity > 0.03 else { continue }
            let radius = CGFloat(0.5 + r1 * 0.5) * CGFloat(1 - t * 0.4)
            let bucket = min(bucketCount - 1, Int(opacity * Double(bucketCount)))
            buckets[bucket].addEllipse(
                in: CGRect(
                    x: px - radius, y: py - radius,
                    width: radius * 2, height: radius * 2))
        }
    }

    private static func drawGlyph(
        _ shape: GlyphShape, x: CGFloat, y: CGFloat, color: RGB, opacity: Double,
        cache: GlyphCache, in context: inout GraphicsContext
    ) {
        if let path = shape.path {
            context.fill(path.applying(CGAffineTransform(translationX: x, y: y)), with: .color(color.color(opacity)))
        } else if shape.isBitmap {
            var layer = context
            layer.opacity = opacity
            layer.draw(
                Text(String(shape.character)).font(Font(cache.font as CTFont)),
                at: CGPoint(x: x, y: y - (cache.ascent - cache.descent) / 2), anchor: .leading)
        }
    }

    /// Letters erode into particles that drift up and away, sweeping left to right.
    private static func dissolve(
        _ glyph: Glyph, x: CGFloat, y: CGFloat, progress: Double, age: Double, edge: Double,
        palette: Palette, cache: GlyphCache,
        buckets: inout [Path], in context: inout GraphicsContext
    ) {
        let bodyOpacity = (1 - agedFade * age) * (1 - smoothstep(0.02, 0.5, progress)) * edge
        if bodyOpacity > 0.01 {
            drawGlyph(
                glyph.shape, x: x, y: y - CGFloat(progress * 2), color: palette.text, opacity: bodyOpacity,
                cache: cache, in: &context)
        }

        var rng = SplitMix64(seed: UInt64(glyph.id) &* 0x2545_F491_4F6C_DD1D)
        let advance = max(glyph.shape.advance, 1)
        for sample in glyph.shape.samples {
            let r1 = Double(rng.unit())
            let r2 = Double(rng.unit())
            let r3 = Double(rng.unit())
            let r4 = Double(rng.unit())
            let r5 = Double(rng.unit())
            let r6 = Double(rng.unit())

            let delay = 0.24 * Double(sample.x / advance) + r1 * 0.12
            let life = min(0.97 - delay, 0.45 + r2 * 0.4)
            let t = (progress - delay) / life
            guard t > 0, t < 1 else { continue }

            let travel = t * t * 0.35 + t * 0.65
            let velocityX = (r3 * 1.4 - 0.4) * 22
            let velocityY = -(8 + r4 * 30)
            let wobble = sin(t * 6 + r5 * 6.283) * 2.5 * t
            let px = x + sample.x + CGFloat(velocityX * travel + wobble)
            let py = y + sample.y + CGFloat(velocityY * travel)
            let radius = CGFloat(0.55 + r6 * 0.75) * CGFloat(1 - t * 0.5)
            let opacity = pow(1 - t, 1.3) * min(1, t * 12) * edge
            guard opacity > 0.03 else { continue }
            let bucket = min(bucketCount - 1, Int(opacity * Double(bucketCount)))
            buckets[bucket].addEllipse(
                in: CGRect(
                    x: px - radius, y: py - radius,
                    width: radius * 2, height: radius * 2))
        }
    }

    /// Words rise slightly, soften and take on the void's violet as they disappear.
    /// Older kept words already lean toward the void (softer, violet), staying in place;
    /// once released they rise, blur and vanish from there.
    private static func fadeIntoVoid(
        _ glyph: Glyph, x: CGFloat, y: CGFloat, progress: Double, age: Double,
        edge: Double, now: Double,
        palette: Palette, cache: GlyphCache, in context: inout GraphicsContext
    ) {
        let aged = age
        let opacity = (1 - agedFade * aged) * pow(1 - progress, 1.6) * edge
        let rise = -12 * CGFloat(1 - pow(1 - progress, 2))
        let color = RGB.mix(palette.text, palette.tint, min(1, 0.7 * aged + progress * 1.5))
        let spread = CGFloat(1.2 * aged + 5 * progress)

        drawGlyph(
            glyph.shape, x: x, y: y + rise, color: color, opacity: opacity * (1 - 0.55 * progress),
            cache: cache, in: &context)
        let halo = opacity * (0.06 * aged + 0.2 * min(1, progress * 4))
        guard halo > 0.01 else { return }
        for (dx, dy) in [(-1.0, 0.0), (1.0, 0.0), (0.0, -1.0), (0.0, 1.0)] {
            drawGlyph(
                glyph.shape, x: x + CGFloat(dx) * spread, y: y + rise + CGFloat(dy) * spread,
                color: color, opacity: halo, cache: cache, in: &context)
        }
    }

    // MARK: - Caret

    private static func drawCaretAndComposition(
        engine: JournalEngine, originX: CGFloat, baseline: CGFloat,
        now: Double, palette: Palette, style: RenderStyle,
        in context: inout GraphicsContext
    ) {
        let cache = engine.glyphCache
        let font = Font(cache.font as CTFont)
        let textX = originX + engine.caretX
        let centerY = baseline - (cache.ascent - cache.descent) / 2

        if !engine.markedText.isEmpty {
            context.draw(
                Text(engine.markedText).font(font).foregroundColor(palette.text.color()),
                at: CGPoint(x: textX, y: centerY), anchor: .leading)
            let underline = Path(CGRect(x: textX, y: baseline + 3, width: engine.markedWidth, height: 1))
            context.fill(underline, with: .color(palette.text.color(0.5)))
        }

        let caret = CGRect(
            x: textX + engine.markedWidth + 1, y: baseline - cache.ascent,
            width: 2, height: cache.ascent + cache.descent)
        engine.caretRect = caret

        if engine.isPristine, let placeholder = style.placeholder {
            context.draw(
                Text(placeholder).font(font).foregroundColor(palette.text.color(0.28)),
                at: CGPoint(x: textX + 8, y: centerY), anchor: .leading)
        }

        guard !engine.caretHidden else { return }
        // Solid while typing, then a calm 1 s blink (matches the 2 Hz idle redraw).
        let idle = now - engine.lastInputTime
        let visible = idle < 0.6 || Int((idle - 0.6) / 0.5) % 2 == 1
        if visible {
            context.fill(Path(roundedRect: caret, cornerRadius: 1), with: .color(palette.caret.color(0.9)))
        }
    }

    private static func smoothstep(_ lower: Double, _ upper: Double, _ value: Double) -> Double {
        let t = min(1, max(0, (value - lower) / (upper - lower)))
        return t * t * (3 - 2 * t)
    }
}
