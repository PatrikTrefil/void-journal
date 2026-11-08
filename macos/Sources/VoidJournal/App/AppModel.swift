import SwiftUI

final class AppModel: ObservableObject {
    let engine = JournalEngine(font: Typeface.stored.font(size: TextSize.stored.pointSize))
    @Published var showingIntro: Bool

    init() {
        showingIntro = !UserDefaults.standard.bool(forKey: PreferenceKey.hasSeenIntro)
    }

    func showIntro() {
        withAnimation(.easeInOut(duration: 0.8)) { showingIntro = true }
    }

    func finishIntro() {
        UserDefaults.standard.set(true, forKey: PreferenceKey.hasSeenIntro)
        withAnimation(.easeInOut(duration: 1.2)) { showingIntro = false }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        Appearance.stored.apply()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let directory = Snapshots.outputDirectory {
            Snapshots.render(to: directory)
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

enum FullScreen {
    @MainActor
    static var window: NSWindow? {
        NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible && $0.canBecomeMain }
    }

    @MainActor
    static var isActive: Bool {
        window?.styleMask.contains(.fullScreen) ?? false
    }

    @MainActor
    static func enter() {
        guard let window, !window.styleMask.contains(.fullScreen) else { return }
        window.toggleFullScreen(nil)
    }
}
