import SwiftUI

struct RGB {
    var red: Double
    var green: Double
    var blue: Double

    init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    func color(_ opacity: Double = 1) -> Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    static func mix(_ a: RGB, _ b: RGB, _ amount: Double) -> RGB {
        RGB(
            a.red + (b.red - a.red) * amount,
            a.green + (b.green - a.green) * amount,
            a.blue + (b.blue - a.blue) * amount)
    }
}

struct Palette {
    let text: RGB
    /// Color words take on as they fade away.
    let tint: RGB
    let caret: RGB

    init(theme: Theme, isDark: Bool) {
        switch (theme, isDark) {
        case (.dissolve, true):
            text = RGB(0.90, 0.90, 0.92)
            tint = RGB(0.90, 0.90, 0.92)
            caret = RGB(0.95, 0.95, 0.97)
        case (.dissolve, false):
            text = RGB(0.13, 0.13, 0.15)
            tint = RGB(0.13, 0.13, 0.15)
            caret = RGB(0.10, 0.10, 0.12)
        case (.void, true):
            text = RGB(0.93, 0.90, 1.00)
            tint = RGB(0.56, 0.38, 0.98)
            caret = RGB(0.78, 0.66, 1.00)
        case (.void, false):
            text = RGB(0.20, 0.13, 0.36)
            tint = RGB(0.66, 0.52, 0.96)
            caret = RGB(0.42, 0.26, 0.82)
        }
    }
}
