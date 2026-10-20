import AppKit
import Carbon.HIToolbox

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let chain = WindowChain()
    private var hotkey: Hotkey?
    private var fullWidthHotkey: Hotkey?
    private var threeFingerScroll: ThreeFingerScroll?
    private let chainSeparator = NSMenuItem.separator()
    private var chainItems: [NSMenuItem] = []
    private let permissionItem = NSMenuItem()
    private let openSettingsItem = NSMenuItem(
        title: "Open Accessibility Settings…",
        action: #selector(openAccessibilitySettings),
        keyEquivalent: ""
    )
    private lazy var settingsWindow = SettingsWindow()

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
        menu.addItem(chainSeparator)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem(
            title: "Quit Window Carousel",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu

        hotkey = Hotkey(keyCode: kVK_ANSI_C, modifiers: controlKey | optionKey) { [weak self] in
            self?.toggleFocusedWindow()
        }
        fullWidthHotkey = Hotkey(keyCode: kVK_ANSI_F, modifiers: controlKey | optionKey) { [weak self] in
            self?.toggleFullWidthOfFocusedWindow()
        }
        threeFingerScroll = ThreeFingerScroll(chain: chain)

        Accessibility.promptIfNeeded()
    }

    func menuWillOpen(_ menu: NSMenu) {
        let granted = Accessibility.isGranted
        permissionItem.title = granted ? "Accessibility: granted" : "Accessibility: not granted"
        openSettingsItem.isHidden = granted
        refreshChainItems(in: menu)
    }

    private func refreshChainItems(in menu: NSMenu) {
        chainItems.forEach(menu.removeItem)
        chain.removeClosed()
        let titles = chain.windows.isEmpty ? ["Chain is empty"] : chain.windows.map(\.menuTitle)
        chainItems = titles.map { NSMenuItem(title: $0, action: nil, keyEquivalent: "") }
        let start = menu.index(of: chainSeparator) + 1
        for (offset, item) in chainItems.enumerated() {
            menu.insertItem(item, at: start + offset)
        }
    }

    private func toggleFocusedWindow() {
        guard let window = Accessibility.focusedWindow() else { return }
        let added = chain.toggle(window)
        guard let area = Screen.usableArea() else { return }
        chain.arrange(in: area, revealingNewest: added)
    }

    private func toggleFullWidthOfFocusedWindow() {
        guard let window = Accessibility.focusedWindow(), let area = Screen.usableArea() else { return }
        chain.toggleFullWidth(window, in: area)
    }

    @objc private func openAccessibilitySettings() {
        Accessibility.openSettings()
    }

    @objc private func showSettings() {
        settingsWindow.show()
    }
}
