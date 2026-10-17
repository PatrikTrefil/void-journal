import SwiftUI

/// `VoidJournal --snapshots <dir>` renders a few frames of each theme offscreen and exits.
/// Used to check the animations without screen-recording permission.
enum Snapshots {
    static var outputDirectory: URL? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--snapshots"), index + 1 < arguments.count else { return nil }
        return URL(fileURLWithPath: arguments[index + 1])
    }

    @MainActor
    static func render(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let text =
            "Today I woke up early and walked to the river. The fog was still sitting on the water "
            + "and everything felt slower than usual. I keep thinking about what she said yesterday."
        for theme in Theme.allCases {
            for isDark in [true, false] {
                let engine = JournalEngine(font: Typeface.serif.font(size: TextSize.medium.pointSize))
                engine.fadeDuration = theme.fadeDuration
                let style = RenderStyle(theme: theme, isDark: isDark, reduceMotion: false)
                let size = CGSize(width: 1000, height: 640)
                let start = JournalEngine.now
                engine.insert(text)
                // Warm up the simulation so a release sweep is underway.
                var t = start
                for _ in 0..<90 {
                    t += 1.0 / 60
                    engine.tick(now: t)
                }
                let short = JournalEngine(font: Typeface.serif.font(size: TextSize.medium.pointSize))
                short.insert("Just a few quiet words drifting toward the void tonight.")
                for step in 0..<300 { short.tick(now: JournalEngine.now + Double(step) / 60) }
                var frames: [(String, JournalEngine, Double)] = [0.0, 0.4, 0.9].enumerated().map {
                    ("\($0.offset)", engine, t + $0.element)
                }
                frames.append(("short", short, JournalEngine.now + 5))
                for (frame, frameEngine, now) in frames {
                    let view = ZStack {
                        Group {
                            if theme == .void {
                                VoidBackground(isDark: isDark, moving: false)
                            } else {
                                DissolveBackground(isDark: isDark)
                            }
                        }
                        Canvas { context, canvasSize in
                            JournalRenderer.draw(
                                engine: frameEngine, in: &context, size: canvasSize, now: now, style: style)
                        }
                    }
                    .frame(width: size.width, height: size.height)
                    .environment(\.colorScheme, isDark ? .dark : .light)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 2
                    guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                        let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
                    else { continue }
                    let name = "\(theme.rawValue)-\(isDark ? "dark" : "light")-\(frame).png"
                    try? png.write(to: directory.appendingPathComponent(name))
                }
            }
        }
    }
}
