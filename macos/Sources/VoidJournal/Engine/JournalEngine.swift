import AppKit
import SwiftUI

struct Glyph {
    let id: Int
    let character: Character
    var shape: GlyphShape
    let isNewline: Bool
    let isSpace: Bool
    var x: CGFloat = 0
    var line = 0
    /// When the glyph was typed (phase for the looping smoke particles).
    let bornAt: Double
    /// 0 → 1: how far kept text has started to let go. Grows with distance from the end of
    /// the text and eases toward its target, so new words never make old ones jump.
    var aging: Double = 0
    /// When the glyph started letting go. May lie slightly in the future (staggered release).
    var releasedAt: Double?

    var isBreak: Bool { isNewline || isSpace }
}

/// Holds the text being written and decides when each character lets go.
///
/// Text only ever grows at the end. Characters before `frontier` have been released and are
/// animating away; characters after it are still "alive" and can be deleted. The frontier is
/// pushed forward at a pace that follows the writer's typing speed, while always keeping the
/// current sentence (bounded to about one line) on screen.
final class JournalEngine: ObservableObject {
    /// Whether the canvas needs to redraw at full frame rate.
    @Published private(set) var isAnimating = false

    /// When false, nothing is released automatically (used by the intro, which releases by hand).
    let autoRelease: Bool
    var fadeDuration: Double = 2.0
    var caretHidden = false

    private(set) var glyphCache: GlyphCache
    private(set) var glyphs: [Glyph] = []
    private(set) var frontier = 0
    private(set) var markedText = ""
    private(set) var markedWidth: CGFloat = 0
    private(set) var caretX: CGFloat = 0
    private(set) var caretLine = 0
    /// Lines that fully dissolved and were removed from the top; keeps vertical motion continuous.
    private(set) var droppedLines = 0
    /// Smoothed absolute caret line, used to glide text upward when a new line starts.
    private(set) var displayLine: Double = 0
    private(set) var lastInputTime: Double = 0
    private(set) var columnWidth: CGFloat = 640
    private(set) var totalTyped = 0
    /// Caret rectangle in view coordinates (y-down), used to place the input method window.
    var caretRect: CGRect = .zero

    private var nextID = 0
    private var rateCounter: Double = 0
    private var rateTime: Double = 0
    private var releaseBudget: Double = 0
    private var lastTick: Double?
    private var wakeGeneration = 0
    private var documentLength = 0

    private static let rateTimeConstant = 2.0
    private static let minimumKeep = 45

    static var now: Double { Date().timeIntervalSinceReferenceDate }

    init(font: NSFont, autoRelease: Bool = true) {
        glyphCache = GlyphCache(font: font)
        self.autoRelease = autoRelease
    }

    var font: NSFont { glyphCache.font }
    var lineHeight: CGFloat { glyphCache.lineHeight }
    var isPristine: Bool { totalTyped == 0 && markedText.isEmpty }
    /// Characters typed per second, smoothed over the last couple of seconds.
    var typingRate: Double { rateCounter / Self.rateTimeConstant }
    var utf16Length: Int { documentLength }

    // MARK: - Configuration

    func setFont(_ font: NSFont) {
        guard font != glyphCache.font else { return }
        glyphCache = GlyphCache(font: font)
        for index in glyphs.indices {
            glyphs[index].shape = glyphCache.shape(for: glyphs[index].character)
        }
        markedWidth = glyphCache.width(of: markedText)
        layout()
        displayLine = Double(droppedLines + caretLine)
    }

    func setColumnWidth(_ width: CGFloat) {
        guard abs(width - columnWidth) > 0.5 else { return }
        columnWidth = width
        layout()
        displayLine = Double(droppedLines + caretLine)
    }

    // MARK: - Editing

    func insert(_ string: String) {
        guard !string.isEmpty else { return }
        let now = Self.now
        for raw in string {
            let character: Character = raw.isNewline ? "\n" : (raw == "\t" ? " " : raw)
            glyphs.append(
                Glyph(
                    id: nextID,
                    character: character,
                    shape: glyphCache.shape(for: character),
                    isNewline: character.isNewline,
                    isSpace: character.isWhitespace && !character.isNewline,
                    bornAt: now))
            nextID += 1
        }
        documentLength += string.utf16.count
        totalTyped += string.count
        registerInput(weight: min(Double(string.count), 3))
        layout()
    }

    func deleteBackward() {
        guard glyphs.count > frontier else { return }
        glyphs.removeLast()
        registerInput(weight: 0)
        layout()
    }

    func deleteWordBackward() {
        while glyphs.count > frontier, glyphs[glyphs.count - 1].isBreak { glyphs.removeLast() }
        while glyphs.count > frontier, !glyphs[glyphs.count - 1].isBreak { glyphs.removeLast() }
        registerInput(weight: 0)
        layout()
    }

    func setMarkedText(_ text: String) {
        markedText = text
        markedWidth = glyphCache.width(of: text)
        registerInput(weight: 0)
    }

    /// Releases everything that is still on screen, sweeping from the first word to the last.
    func releaseAll(stagger: Double = 0.012) {
        let now = Self.now
        var start = now
        for index in frontier..<glyphs.count {
            glyphs[index].releasedAt = start
            if !glyphs[index].isBreak { start += stagger }
        }
        frontier = glyphs.count
        wake()
    }

    func reset() {
        glyphs = []
        frontier = 0
        droppedLines = 0
        displayLine = 0
        markedText = ""
        markedWidth = 0
        releaseBudget = 0
        caretHidden = false
        layout()
        wake()
    }

    private func registerInput(weight: Double) {
        let now = Self.now
        decayRate(to: now)
        rateCounter += weight
        lastInputTime = now
        wake()
    }

    private func decayRate(to now: Double) {
        rateCounter *= exp(-max(0, now - rateTime) / Self.rateTimeConstant)
        rateTime = now
    }

    private func wake() {
        wakeGeneration += 1
        if !isAnimating { isAnimating = true }
    }

    // MARK: - Layout

    /// Greedy word wrap. Only ever restarts at the top of a line, so dropping finished
    /// lines from the front never changes how the remaining lines wrap.
    private func layout() {
        var x: CGFloat = 0
        var line = 0
        var lastBreak: Int?
        for index in glyphs.indices {
            let advance = glyphs[index].shape.advance
            if glyphs[index].isNewline {
                glyphs[index].x = x
                glyphs[index].line = line
                line += 1
                x = 0
                lastBreak = nil
                continue
            }
            if glyphs[index].isSpace {
                glyphs[index].x = x
                glyphs[index].line = line
                x += advance
                lastBreak = index
                continue
            }
            if x + advance > columnWidth && x > 0 {
                line += 1
                x = 0
                if let breakIndex = lastBreak {
                    for moved in (breakIndex + 1)..<index {
                        glyphs[moved].x = x
                        glyphs[moved].line = line
                        x += glyphs[moved].shape.advance
                    }
                }
                lastBreak = nil
            }
            glyphs[index].x = x
            glyphs[index].line = line
            x += advance
        }
        caretX = x
        caretLine = line
    }

    // MARK: - Pacing

    /// Index before which characters may be released: everything except the current
    /// sentence, which is kept between `minimumKeep` characters and roughly one and a half lines.
    private func targetFrontier() -> Int {
        let count = glyphs.count
        guard autoRelease, count > Self.minimumKeep else { return frontier }
        let maximumKeep = max(72, Int(columnWidth * 1.5 / max(glyphCache.averageAdvance, 1)))

        var sentenceStart = max(0, count - maximumKeep)
        var index = count - 1
        while index > 0 && index >= count - maximumKeep {
            if glyphs[index].isNewline {
                sentenceStart = index + 1
                break
            }
            if glyphs[index].isSpace && ".!?…".contains(glyphs[index - 1].character) {
                sentenceStart = index + 1
                break
            }
            index -= 1
        }

        var keep = min(sentenceStart, count - Self.minimumKeep)
        // Never cut a word in half.
        while keep > 0 && !glyphs[keep - 1].isBreak { keep -= 1 }
        if count - keep > maximumKeep {
            keep = count - maximumKeep
            while keep < count && !glyphs[keep - 1].isBreak { keep += 1 }
        }
        return max(frontier, keep)
    }

    /// Advances the simulation. Called once per rendered frame.
    func tick(now: Double) {
        let dt = min(max(now - (lastTick ?? now), 0), 0.1)
        lastTick = now
        decayRate(to: now)

        let target = targetFrontier()
        if target > frontier {
            let backlog = Double(target - frontier)
            // Follow the writer: faster typing releases faster, a large backlog catches up,
            // and when the writer pauses the last words drift off slowly.
            let speed = max(3.0, typingRate * 1.1, backlog * 0.5)
            releaseBudget = min(releaseBudget + speed * dt, 8)
            while frontier < target {
                if !glyphs[frontier].isBreak {
                    guard releaseBudget >= 1 else { break }
                    releaseBudget -= 1
                }
                glyphs[frontier].releasedAt = now
                frontier += 1
            }
        } else {
            releaseBudget = min(releaseBudget, 1)
        }

        updateAging(dt: dt)
        dropFinishedLines(now: now)

        let targetLine = Double(droppedLines + caretLine)
        displayLine += (targetLine - displayLine) * (1 - exp(-dt * 9))
        if abs(targetLine - displayLine) < 0.0005 { displayLine = targetLine }

        updateAnimating(now: now, target: target)
    }

    /// The last two words are left untouched; from there the effect builds up over the next
    /// few words, getting stronger the further back the text is.
    private func updateAging(dt: Double) {
        let untouchedWords = 2
        let rampWords = 6.0
        let easing = 1 - exp(-dt / 0.9)
        var wordsFromEnd = 0
        var index = glyphs.count - 1
        while index >= 0 {
            if glyphs[index].isBreak && index + 1 < glyphs.count && !glyphs[index + 1].isBreak {
                wordsFromEnd += 1
            }
            var target = min(1, max(0, Double(wordsFromEnd - untouchedWords + 1) / rampWords))
            // Released glyphs never regain contrast while they fade out.
            if glyphs[index].releasedAt != nil { target = max(target, glyphs[index].aging) }
            glyphs[index].aging += (target - glyphs[index].aging) * easing
            index -= 1
        }
    }

    private func isFinished(_ glyph: Glyph, now: Double) -> Bool {
        guard let releasedAt = glyph.releasedAt else { return false }
        return now - releasedAt > fadeDuration
    }

    private func dropFinishedLines(now: Double) {
        guard !glyphs.isEmpty else { return }

        // Everything gone: start a fresh line so the caret does not sit after invisible text.
        if frontier == glyphs.count && glyphs.allSatisfy({ isFinished($0, now: now) }) {
            droppedLines += caretLine + 1
            glyphs.removeAll()
            frontier = 0
            layout()
            return
        }

        var dropped = false
        while let first = glyphs.first, first.line < caretLine {
            var count = 0
            while count < glyphs.count && glyphs[count].line == first.line {
                guard isFinished(glyphs[count], now: now) else {
                    if dropped { layout() }
                    return
                }
                count += 1
            }
            glyphs.removeFirst(count)
            frontier -= count
            droppedLines += 1
            dropped = true
            layout()
        }
    }

    private func updateAnimating(now: Double, target: Int) {
        // Kept text is never fully still: it slowly shows that it is letting go.
        var animating =
            target > frontier
            || frontier < glyphs.count
            || abs(displayLine - Double(droppedLines + caretLine)) > 0.0005
        if !animating {
            for index in 0..<frontier {
                if let releasedAt = glyphs[index].releasedAt, now - releasedAt < fadeDuration {
                    animating = true
                    break
                }
            }
        }
        guard animating != isAnimating else { return }
        // Publishing from inside a render pass is not allowed; defer, and skip if input arrived since.
        let generation = wakeGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.wakeGeneration == generation else { return }
            self.isAnimating = animating
        }
    }
}
