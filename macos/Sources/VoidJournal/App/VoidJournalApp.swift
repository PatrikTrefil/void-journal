import SwiftUI

@main
struct VoidJournalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @AppStorage(PreferenceKey.theme) private var theme: Theme = .void
    @AppStorage(PreferenceKey.textSize) private var textSize: TextSize = .standard

    var body: some Scene {
        Window("Void Journal", id: "journal") {
            JournalView()
                .environmentObject(model)
                .frame(minWidth: 560, minHeight: 420)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Let Everything Go") { model.engine.releaseAll() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(model.showingIntro)
            }
            CommandGroup(before: .toolbar) {
                ForEach(Array(Theme.allCases.enumerated()), id: \.element) { index, option in
                    Toggle(
                        option.title,
                        isOn: Binding(
                            get: { theme == option },
                            set: { if $0 { theme = option } })
                    )
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                }
                Divider()
                Button("Bigger") { textSize = textSize.bigger ?? textSize }
                    .keyboardShortcut("+", modifiers: .command)
                    .disabled(textSize.bigger == nil)
                Button("Smaller") { textSize = textSize.smaller ?? textSize }
                    .keyboardShortcut("-", modifiers: .command)
                    .disabled(textSize.smaller == nil)
                Button("Default Size") { textSize = .standard }
                    .keyboardShortcut("0", modifiers: .command)
                    .disabled(textSize == .standard)
                Divider()
            }
            CommandGroup(replacing: .help) {
                Button("Show Introduction") { model.showIntro() }
            }
        }

        Settings {
            SettingsView()
        }
    }
}
