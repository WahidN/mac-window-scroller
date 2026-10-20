import AppKit
import ApplicationServices

enum Accessibility {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    static func promptIfNeeded() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func focusedWindow() -> ChainWindow? {
        guard isGranted, let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value
        else { return nil }
        return ChainWindow(element: value as! AXUIElement, appName: app.localizedName ?? "Unknown")
    }

    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
