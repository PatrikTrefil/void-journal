import AppKit
import SwiftUI

/// Invisible, full-window view that receives keyboard input and feeds it to the engine.
/// Implements `NSTextInputClient` so dead keys, accents and input methods work natively.
final class InputCaptureView: NSView, NSTextInputClient {
    var engine: JournalEngine?
    var isEnabled = true
    private var chromeHidden = false

    override var acceptsFirstResponder: Bool { isEnabled }
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        focus()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect],
                owner: self, userInfo: nil))
    }

    func focus() {
        guard isEnabled, let window, window.firstResponder !== self else { return }
        window.makeFirstResponder(self)
    }

    override func mouseDown(with event: NSEvent) {
        focus()
        super.mouseDown(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        setChromeHidden(false)
    }

    override func keyDown(with event: NSEvent) {
        guard isEnabled, engine != nil else {
            super.keyDown(with: event)
            return
        }
        NSCursor.setHiddenUntilMouseMoves(true)
        setChromeHidden(true)
        interpretKeyEvents([event])
    }

    /// Fades the traffic-light buttons while writing; they return when the mouse moves.
    private func setChromeHidden(_ hidden: Bool) {
        guard hidden != chromeHidden, let titlebar = window?.standardWindowButton(.closeButton)?.superview else {
            return
        }
        chromeHidden = hidden
        NSAnimationContext.runAnimationGroup { context in
            context.duration = hidden ? 0.6 : 0.25
            titlebar.animator().alphaValue = hidden ? 0 : 1
        }
    }

    @objc func paste(_ sender: Any?) {
        guard isEnabled, let string = NSPasteboard.general.string(forType: .string) else { return }
        engine?.insert(string)
    }

    // MARK: - Key bindings

    override func doCommand(by selector: Selector) {
        guard let engine else { return }
        switch selector {
        case #selector(NSResponder.deleteBackward(_:)):
            engine.deleteBackward()
        case #selector(NSResponder.deleteWordBackward(_:)), #selector(NSResponder.deleteToBeginningOfLine(_:)):
            engine.deleteWordBackward()
        case #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.insertLineBreak(_:)),
            #selector(NSResponder.insertParagraphSeparator(_:)):
            engine.insert("\n")
        case #selector(NSResponder.insertTab(_:)):
            engine.insert(" ")
        default:
            // Writing only moves forward: arrows and other navigation are intentionally ignored.
            break
        }
    }

    // MARK: - NSTextInputClient

    private func plainString(_ value: Any) -> String {
        (value as? NSAttributedString)?.string ?? (value as? String) ?? ""
    }

    func insertText(_ string: Any, replacementRange: NSRange) {
        engine?.setMarkedText("")
        engine?.insert(plainString(string))
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        engine?.setMarkedText(plainString(string))
    }

    func unmarkText() {
        guard let engine, !engine.markedText.isEmpty else { return }
        let text = engine.markedText
        engine.setMarkedText("")
        engine.insert(text)
    }

    func selectedRange() -> NSRange {
        guard let engine else { return NSRange(location: 0, length: 0) }
        return NSRange(location: engine.utf16Length + engine.markedText.utf16.count, length: 0)
    }

    func markedRange() -> NSRange {
        guard let engine, !engine.markedText.isEmpty else { return NSRange(location: NSNotFound, length: 0) }
        return NSRange(location: engine.utf16Length, length: engine.markedText.utf16.count)
    }

    func hasMarkedText() -> Bool {
        !(engine?.markedText.isEmpty ?? true)
    }

    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        nil
    }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        []
    }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        guard let engine, let window else { return .zero }
        return window.convertToScreen(convert(engine.caretRect, to: nil))
    }

    func characterIndex(for point: NSPoint) -> Int {
        NSNotFound
    }
}

struct InputCapture: NSViewRepresentable {
    let engine: JournalEngine
    var isEnabled: Bool

    func makeNSView(context: Context) -> InputCaptureView {
        let view = InputCaptureView()
        view.engine = engine
        return view
    }

    func updateNSView(_ view: InputCaptureView, context: Context) {
        view.engine = engine
        view.isEnabled = isEnabled
        if isEnabled {
            DispatchQueue.main.async { view.focus() }
        }
    }
}
