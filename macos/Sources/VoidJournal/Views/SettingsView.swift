import SwiftUI

struct SettingsView: View {
    @AppStorage(PreferenceKey.theme) private var theme: Theme = .void
    @AppStorage(PreferenceKey.appearance) private var appearance: Appearance = .system
    @AppStorage(PreferenceKey.movingGradients) private var movingGradients = true
    @AppStorage(PreferenceKey.typeface) private var typeface: Typeface = .serif
    @AppStorage(PreferenceKey.textSize) private var textSize: TextSize = .standard

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $theme) {
                    ForEach(Theme.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Moving gradients", isOn: $movingGradients)
                    .disabled(theme != .void)
            } footer: {
                Text(theme.summary)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                }
                Picker("Typeface", selection: $typeface) {
                    ForEach(Typeface.allCases) { Text($0.title).tag($0) }
                }
                Picker("Text size", selection: $textSize) {
                    ForEach(TextSize.allCases) { Text($0.title).tag($0) }
                }
            } footer: {
                Text("Nothing you write is ever saved.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize()
        .onChange(of: appearance) { appearance.apply() }
    }
}
