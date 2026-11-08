import AppKit
import CoreText
import SwiftUI

/// The outline of a single grapheme, pre-computed once per character and font.
/// Coordinates are y-down, relative to the glyph's baseline-left origin.
final class GlyphShape {
    let character: Character
    let path: Path?
    let advance: CGFloat
    /// True for glyphs without an outline (e.g. color emoji); these are drawn as text.
    let isBitmap: Bool
    /// Points inside the glyph outline that particles are emitted from.
    let samples: [CGPoint]

    init(character: Character, path: Path?, advance: CGFloat, isBitmap: Bool, samples: [CGPoint]) {
        self.character = character
        self.path = path
        self.advance = advance
        self.isBitmap = isBitmap
        self.samples = samples
    }
}

final class GlyphCache {
    let font: NSFont
    let ascent: CGFloat
    let descent: CGFloat
    let lineHeight: CGFloat
    private(set) var averageAdvance: CGFloat = 10
    private var shapes: [Character: GlyphShape] = [:]

    init(font: NSFont, lineSpacing: CGFloat = 1.65) {
        self.font = font
        ascent = font.ascender
        descent = -font.descender
        lineHeight = ceil((ascent + descent) * lineSpacing)
        let sample = "the quick brown fox jumps over the lazy dog"
        averageAdvance = sample.reduce(0) { $0 + shape(for: $1).advance } / CGFloat(sample.count)
    }

    func shape(for character: Character) -> GlyphShape {
        if let cached = shapes[character] { return cached }
        let shape = makeShape(character)
        shapes[character] = shape
        return shape
    }

    func width(of string: String) -> CGFloat {
        string.reduce(0) { $0 + shape(for: $1).advance }
    }

    private func makeShape(_ character: Character) -> GlyphShape {
        if character.isNewline {
            return GlyphShape(character: character, path: nil, advance: 0, isBitmap: false, samples: [])
        }

        // Going through CTLine gives us font fallback for free (diacritics, CJK, emoji…).
        let attributed = NSAttributedString(string: String(character), attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attributed)
        let advance = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let outline = CGMutablePath()
        var isBitmap = false

        let runs = (CTLineGetGlyphRuns(line) as? [CTRun]) ?? []
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            let attributes = CTRunGetAttributes(run) as NSDictionary
            guard let fontValue = attributes[kCTFontAttributeName] else { continue }
            let runFont = fontValue as! CTFont
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            for index in 0..<count {
                if let glyphPath = CTFontCreatePathForGlyph(runFont, glyphs[index], nil) {
                    // Flip CoreText's y-up glyph space into SwiftUI's y-down space.
                    let transform = CGAffineTransform(
                        a: 1, b: 0, c: 0, d: -1,
                        tx: positions[index].x, ty: -positions[index].y)
                    outline.addPath(glyphPath, transform: transform)
                } else if !character.isWhitespace {
                    isBitmap = true
                }
            }
        }

        var rng = SplitMix64(seed: UInt64(truncatingIfNeeded: String(character).hashValue))
        var samples: [CGPoint] = []
        if isBitmap {
            for _ in 0..<40 {
                samples.append(
                    CGPoint(
                        x: rng.unit() * advance,
                        y: -ascent * 0.85 + rng.unit() * ascent * 0.95))
            }
        } else if !outline.isEmpty {
            let box = outline.boundingBoxOfPath
            let density = font.pointSize * 0.3
            let target = max(10, min(52, Int(box.width * box.height / density)))
            var attempts = 0
            while samples.count < target && attempts < target * 40 {
                attempts += 1
                let point = CGPoint(
                    x: box.minX + rng.unit() * box.width,
                    y: box.minY + rng.unit() * box.height)
                if outline.contains(point, using: .winding) { samples.append(point) }
            }
        }

        return GlyphShape(
            character: character,
            path: outline.isEmpty ? nil : Path(outline),
            advance: advance,
            isBitmap: isBitmap,
            samples: samples)
    }
}

/// Small, fast, deterministic RNG so every glyph dissolves the same way on every frame.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> CGFloat {
        CGFloat(next() >> 11) / CGFloat(UInt64(1) << 53)
    }
}
