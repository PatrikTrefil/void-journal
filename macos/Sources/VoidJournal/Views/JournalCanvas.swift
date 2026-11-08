import SwiftUI

/// Redraws every frame while something is moving, and at 2 Hz (caret blink) when idle.
struct JournalCanvas: View {
    @ObservedObject var engine: JournalEngine
    let style: RenderStyle

    var body: some View {
        TimelineView(.animation(minimumInterval: engine.isAnimating ? nil : 0.5)) { timeline in
            Canvas { context, size in
                JournalRenderer.draw(
                    engine: engine, in: &context, size: size,
                    now: timeline.date.timeIntervalSinceReferenceDate, style: style)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
