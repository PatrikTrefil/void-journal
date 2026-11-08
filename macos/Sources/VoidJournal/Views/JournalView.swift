import SwiftUI

struct JournalView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(PreferenceKey.theme) private var theme: Theme = .void
    @AppStorage(PreferenceKey.appearance) private var appearance: Appearance = .system
    @AppStorage(PreferenceKey.movingGradients) private var movingGradients = true
    @AppStorage(PreferenceKey.typeface) private var typeface: Typeface = .serif
    @AppStorage(PreferenceKey.textSize) private var textSize: TextSize = .standard
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ThemeBackground(theme: theme, moving: movingGradients && !reduceMotion)

            if !model.showingIntro {
                JournalCanvas(
                    engine: model.engine,
                    style: RenderStyle(
                        theme: theme,
                        isDark: colorScheme == .dark,
                        reduceMotion: reduceMotion,
                        maxColumnWidth: textSize.maxColumnWidth,
                        placeholder: "What’s on your mind?")
                )
                .transition(.opacity)
            }

            InputCapture(engine: model.engine, isEnabled: !model.showingIntro)

            if model.showingIntro {
                IntroView()
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .onChange(of: appearance) { appearance.apply() }
        .onChange(of: typeface) { updateFont() }
        .onChange(of: textSize) { updateFont() }
    }

    private func updateFont() {
        model.engine.setFont(typeface.font(size: textSize.pointSize))
    }
}
