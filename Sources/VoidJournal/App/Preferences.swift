import AppKit

enum PreferenceKey {
    static let theme = "theme"
    static let appearance = "appearance"
    static let movingGradients = "movingGradients"
    static let typeface = "typeface"
    static let textSize = "textSize"
    static let hasSeenIntro = "hasSeenIntro"
}

enum Theme: String, CaseIterable, Identifiable {
    case dissolve
    case void

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dissolve: "Dissolve"
        case .void: "Void"
        }
    }

    var summary: String {
        switch self {
        case .dissolve: "Letters break apart into drifting particles."
        case .void: "Words fade into slowly moving purple gradients."
        }
    }

    var fadeDuration: Double {
        switch self {
        case .dissolve: 2.0
        case .void: 2.8
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    @MainActor
    func apply() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    static var stored: Appearance {
        UserDefaults.standard.string(forKey: PreferenceKey.appearance).flatMap(Appearance.init) ?? .system
    }
}

enum Typeface: String, CaseIterable, Identifiable {
    case serif
    case sans
    case mono

    var id: String { rawValue }

    var title: String {
        switch self {
        case .serif: "Serif"
        case .sans: "Sans Serif"
        case .mono: "Monospaced"
        }
    }

    static let introSize: CGFloat = 30

    func font(size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size)
        let design: NSFontDescriptor.SystemDesign =
            switch self {
            case .serif: .serif
            case .sans: .default
            case .mono: .monospaced
            }
        guard let descriptor = base.fontDescriptor.withDesign(design),
            let font = NSFont(descriptor: descriptor, size: size)
        else { return base }
        return font
    }

    static var stored: Typeface {
        UserDefaults.standard.string(forKey: PreferenceKey.typeface).flatMap(Typeface.init) ?? .serif
    }
}

enum TextSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large
    case extraLarge

    /// The size used until the user picks another one.
    static let standard = TextSize.large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }

    var pointSize: CGFloat {
        switch self {
        case .small: 18
        case .medium: 22
        case .large: 28
        case .extraLarge: 34
        }
    }

    /// Widest text column for this size, keeping a comfortable line length.
    var maxColumnWidth: CGFloat { 680 * pointSize / TextSize.medium.pointSize }

    var bigger: TextSize? { neighbor(offset: 1) }
    var smaller: TextSize? { neighbor(offset: -1) }

    private func neighbor(offset: Int) -> TextSize? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), all.indices.contains(index + offset) else { return nil }
        return all[index + offset]
    }

    static var stored: TextSize {
        UserDefaults.standard.string(forKey: PreferenceKey.textSize).flatMap(TextSize.init) ?? .standard
    }
}
