import AppKit
import SwiftUI

@MainActor
final class SettingsWindow {
    private let window = ClosableWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)

    init() {
        window.title = "Settings"
        window.isReleasedWhenClosed = false
    }

    func show() {
        let isFirstShow = window.contentViewController == nil
        // A fresh view reads the login item state again, it can change in System Settings
        window.contentViewController = NSHostingController(rootView: SettingsView())
        if isFirstShow { window.center() }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

// The app has no main menu, so there is no Close item to handle ⌘W
private final class ClosableWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers == "w" {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

private struct SettingsView: View {
    @State private var startsAtLogin = LoginItem.isEnabled
    @State private var needsApproval = LoginItem.needsApproval
    @State private var error: String?

    var body: some View {
        VStack(spacing: 12) {
            Text("Window Carousel").font(.title2.bold())
            Text(Self.version).foregroundStyle(.secondary)
            Text("Made by Wahid Dev").foregroundStyle(.secondary)
            Divider()
            Toggle("Start at login", isOn: Binding(get: { startsAtLogin }, set: { setStartsAtLogin($0) }))
            if needsApproval {
                Text("macOS needs your approval in System Settings.")
                Button("Open Login Items") { LoginItem.openSystemSettings() }
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }
        }
        .padding(24)
        .frame(width: 300)
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    private func setStartsAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        startsAtLogin = LoginItem.isEnabled
        needsApproval = LoginItem.needsApproval
    }
}
