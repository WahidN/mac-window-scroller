import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let permissionItem = NSMenuItem()
    private let openSettingsItem = NSMenuItem(
        title: "Open Accessibility Settings…",
        action: #selector(openAccessibilitySettings),
        keyEquivalent: ""
    )

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = NSImage(
            systemSymbolName: "rectangle.split.3x1",
            accessibilityDescription: "Window Carousel"
        )

        let menu = NSMenu()
        menu.delegate = self
        openSettingsItem.target = self
        menu.addItem(permissionItem)
        menu.addItem(openSettingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Window Carousel",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu

        Accessibility.promptIfNeeded()
    }

    func menuWillOpen(_ menu: NSMenu) {
        let granted = Accessibility.isGranted
        permissionItem.title = granted ? "Accessibility: granted" : "Accessibility: not granted"
        openSettingsItem.isHidden = granted
    }

    @objc private func openAccessibilitySettings() {
        Accessibility.openSettings()
    }
}
