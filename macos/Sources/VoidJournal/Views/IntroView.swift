import SwiftUI

/// First-launch introduction. It explains the idea by doing it: each sentence is typed out
/// and then lets go with the current theme's animation. It ends by recommending full screen.
struct IntroView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(PreferenceKey.theme) private var theme: Theme = .void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var state = IntroState()

    private var engine: JournalEngine { state.engine }

    private static let pages = [
        "Write whatever is on your mind.",
        "As you write, your words slowly let go.",
        "Nothing is saved. Nothing is kept.",
    ]

    var body: some View {
        ZStack {
            JournalCanvas(
                engine: engine,
                style: RenderStyle(
                    theme: theme,
                    isDark: colorScheme == .dark,
                    reduceMotion: reduceMotion,
                    verticalAnchor: 0.5,
                    maxColumnWidth: state.columnWidth))

            if state.showingFinalCard {
                finalCard
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button("Skip") { skip() }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .keyboardShortcut(.cancelAction)
                            .padding(28)
                    }
                }
            }
        }
        .onAppear {
            state.isFullScreen = FullScreen.isActive
            state.script = Task { await runScript() }
        }
        .onDisappear { state.script?.cancel() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            state.isFullScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            state.isFullScreen = false
        }
    }

    private var finalCard: some View {
        VStack(spacing: 22) {
            Text("Void Journal")
                .font(.system(size: 46, weight: .regular, design: .serif))
            Text(
                state.isFullScreen
                    ? "Only your latest thought stays with you.\nTake a breath, and begin."
                    : "Only your latest thought stays with you.\nFor full immersion, write in full screen."
            )
            .font(.title3)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

            Picker("Theme", selection: $theme) {
                ForEach(Theme.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
            .padding(.top, 6)

            HStack(spacing: 12) {
                if state.isFullScreen {
                    Button("Begin Writing") { model.finishIntro() }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Not Now") { model.finishIntro() }
                    Button("Enter Full Screen") {
                        FullScreen.enter()
                        model.finishIntro()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)

            Text("Toggle full screen anytime with ⌃⌘F")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
    }

    @MainActor
    private func runScript() async {
        for page in Self.pages {
            engine.reset()
            state.columnWidth = engine.glyphCache.width(of: page) + 4
            guard await pause(0.4) else { return }

            for character in page {
                engine.insert(String(character))
                let delay: Double =
                    switch character {
                    case ".", ",": 0.22
                    case " ": 0.06
                    default: .random(in: 0.03...0.065)
                    }
                guard await pause(delay) else { return }
            }
            guard await pause(1.1) else { return }

            let stagger = 0.018
            engine.caretHidden = true
            engine.releaseAll(stagger: stagger)
            // Move on while the last letters are still fading out.
            guard await pause(theme.fadeDuration * 0.85 + Double(page.count) * stagger) else { return }
        }
        engine.reset()
        engine.caretHidden = true
        withAnimation(.easeInOut(duration: 0.9)) { state.showingFinalCard = true }
    }

    private func skip() {
        state.script?.cancel()
        engine.caretHidden = true
        engine.releaseAll(stagger: 0.01)
        withAnimation(.easeInOut(duration: 0.8)) { state.showingFinalCard = true }
    }

    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled
    }
}

/// Holds the intro's mutable state. (`@State` is a macro in the macOS 27 SDK whose plugin
/// ships only with Xcode, so an `ObservableObject` keeps the app buildable with the CLI tools.)
final class IntroState: ObservableObject {
    let engine = JournalEngine(font: Typeface.stored.font(size: Typeface.introSize), autoRelease: false)
    @Published var showingFinalCard = false
    @Published var columnWidth: CGFloat = 600
    @Published var isFullScreen = false
    var script: Task<Void, Never>?
}
