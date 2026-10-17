import SwiftUI

struct ThemeBackground: View {
    let theme: Theme
    let moving: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            switch theme {
            case .dissolve:
                DissolveBackground(isDark: colorScheme == .dark)
                    .transition(.opacity)
            case .void:
                VoidBackground(isDark: colorScheme == .dark, moving: moving)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.9), value: theme)
        .ignoresSafeArea()
    }
}

/// Quiet paper (light) or ink (dark) with a barely-there vignette.
struct DissolveBackground: View {
    let isDark: Bool

    var body: some View {
        let base = isDark ? RGB(0.055, 0.055, 0.066) : RGB(0.972, 0.965, 0.945)
        let edge = isDark ? RGB(0.02, 0.02, 0.025) : RGB(0.91, 0.90, 0.875)
        GeometryReader { proxy in
            RadialGradient(
                colors: [base.color(), edge.color()],
                center: UnitPoint(x: 0.5, y: 0.45),
                startRadius: 0,
                endRadius: max(proxy.size.width, proxy.size.height) * 0.75)
        }
    }
}

/// Deep space with soft purple nebulae that drift on slow Lissajous paths.
struct VoidBackground: View {
    let isDark: Bool
    let moving: Bool

    private struct Blob {
        let color: RGB
        let opacity: Double
        let center: CGPoint
        let amplitude: CGSize
        let period: CGSize
        let phase: Double
        let radius: CGFloat
    }

    private static let darkBlobs = [
        Blob(
            color: RGB(0.40, 0.14, 0.72), opacity: 0.55, center: CGPoint(x: 0.22, y: 0.30),
            amplitude: CGSize(width: 0.14, height: 0.12), period: CGSize(width: 53, height: 41), phase: 0.0,
            radius: 0.55),
        Blob(
            color: RGB(0.16, 0.10, 0.50), opacity: 0.65, center: CGPoint(x: 0.80, y: 0.70),
            amplitude: CGSize(width: 0.12, height: 0.14), period: CGSize(width: 61, height: 47), phase: 1.7,
            radius: 0.60),
        Blob(
            color: RGB(0.58, 0.16, 0.58), opacity: 0.35, center: CGPoint(x: 0.70, y: 0.20),
            amplitude: CGSize(width: 0.16, height: 0.10), period: CGSize(width: 71, height: 59), phase: 3.1,
            radius: 0.45),
        Blob(
            color: RGB(0.26, 0.12, 0.62), opacity: 0.50, center: CGPoint(x: 0.30, y: 0.85),
            amplitude: CGSize(width: 0.18, height: 0.08), period: CGSize(width: 67, height: 43), phase: 4.4,
            radius: 0.50),
    ]

    private static let lightBlobs = [
        Blob(
            color: RGB(0.78, 0.66, 0.99), opacity: 0.60, center: CGPoint(x: 0.22, y: 0.30),
            amplitude: CGSize(width: 0.14, height: 0.12), period: CGSize(width: 53, height: 41), phase: 0.0,
            radius: 0.55),
        Blob(
            color: RGB(0.68, 0.73, 0.99), opacity: 0.55, center: CGPoint(x: 0.80, y: 0.70),
            amplitude: CGSize(width: 0.12, height: 0.14), period: CGSize(width: 61, height: 47), phase: 1.7,
            radius: 0.60),
        Blob(
            color: RGB(0.94, 0.72, 0.93), opacity: 0.50, center: CGPoint(x: 0.70, y: 0.20),
            amplitude: CGSize(width: 0.16, height: 0.10), period: CGSize(width: 71, height: 59), phase: 3.1,
            radius: 0.45),
        Blob(
            color: RGB(0.82, 0.70, 1.00), opacity: 0.55, center: CGPoint(x: 0.30, y: 0.85),
            amplitude: CGSize(width: 0.18, height: 0.08), period: CGSize(width: 67, height: 43), phase: 4.4,
            radius: 0.50),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !moving)) { timeline in
            Canvas { context, size in
                draw(
                    in: &context, size: size,
                    time: moving ? timeline.date.timeIntervalSinceReferenceDate : 0)
            }
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let base = isDark ? RGB(0.035, 0.02, 0.07) : RGB(0.957, 0.942, 0.985)
        let bounds = CGRect(origin: .zero, size: size)
        let extent = max(size.width, size.height)
        context.fill(Path(bounds), with: .color(base.color()))

        var nebula = context
        nebula.blendMode = isDark ? .screen : .normal
        for blob in isDark ? Self.darkBlobs : Self.lightBlobs {
            let x = blob.center.x + blob.amplitude.width * sin(time * 2 * .pi / blob.period.width + blob.phase)
            let y = blob.center.y + blob.amplitude.height * cos(time * 2 * .pi / blob.period.height + blob.phase * 1.3)
            let breathe = 1 + 0.07 * sin(time * 2 * .pi / 23 + blob.phase)
            let radius = extent * blob.radius * breathe
            let center = CGPoint(x: x * size.width, y: y * size.height)
            let gradient = Gradient(stops: [
                .init(color: blob.color.color(blob.opacity), location: 0),
                .init(color: blob.color.color(blob.opacity * 0.45), location: 0.45),
                .init(color: blob.color.color(0), location: 1),
            ])
            nebula.fill(
                Path(
                    ellipseIn: CGRect(
                        x: center.x - radius, y: center.y - radius,
                        width: radius * 2, height: radius * 2)),
                with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius))
        }

        // A calm, darker (or lighter) hollow behind the writing line keeps text legible.
        let hollowCenter = CGPoint(x: size.width / 2, y: size.height * 0.45)
        let hollow = Gradient(colors: [base.color(isDark ? 0.7 : 0.6), base.color(0)])
        context.fill(
            Path(bounds),
            with: .radialGradient(
                hollow, center: hollowCenter,
                startRadius: 0, endRadius: extent * 0.42))
    }
}
