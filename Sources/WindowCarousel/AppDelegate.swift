import AppKit
import Carbon.HIToolbox
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let chain = WindowChain()
    private var hotkey: Hotkey?
    private var fullWidthHotkey: Hotkey?
    private var moveLeftHotkey: Hotkey?
    private var moveRightHotkey: Hotkey?
    private var dropHotkey: Hotkey?
    private lazy var stripMotion = StripMotion(chain: chain)
    private var threeFingerScroll: ThreeFingerScroll?
    private var mouseScroll: MouseScroll?
    private let chainSeparator = NSMenuItem.separator()
    private var chainItems: [NSMenuItem] = []
    private let permissionItem = NSMenuItem()
    private let openSettingsItem = NSMenuItem(
        title: "Open Accessibility Settings…",
        action: #selector(openAccessibilitySettings),
        keyEquivalent: ""
    )
    private let updates = UpdateController()
    private let updateItem = NSMenuItem()
    private lazy var settingsWindow = SettingsWindow(updates: updates)

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        openSettingsItem.target = self
        updateItem.target = self
        updateItem.action = #selector(showSettings)
        menu.addItem(updateItem)
        menu.addItem(permissionItem)
        menu.addItem(openSettingsItem)
        menu.addItem(chainSeparator)
        menu.addItem(.separator())
        let shortcutsItem = NSMenuItem(title: "Keyboard Shortcuts", action: #selector(showShortcuts), keyEquivalent: "")
        shortcutsItem.target = self
        shortcutsItem.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        menu.addItem(shortcutsItem)
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
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
        moveLeftHotkey = Hotkey(keyCode: kVK_LeftArrow, modifiers: controlKey | optionKey) { [weak self] in
            self?.moveFocusedWindow(by: -1)
        }
        moveRightHotkey = Hotkey(keyCode: kVK_RightArrow, modifiers: controlKey | optionKey) { [weak self] in
            self?.moveFocusedWindow(by: 1)
        }
        dropHotkey = Hotkey(keyCode: kVK_ANSI_X, modifiers: controlKey | optionKey) { [weak self] in
            self?.chain.dropBordered()
        }
        threeFingerScroll = ThreeFingerScroll(chain: chain, motion: stripMotion)
        startMouseScrollIfNeeded()
        updates.onReleaseChange = { [weak self] in self?.refreshUpdateIndicators() }
        refreshUpdateIndicators()
        updates.start()

        Accessibility.promptIfNeeded()
    }

    private func startMouseScrollIfNeeded() {
        guard mouseScroll == nil, Accessibility.isGranted else { return }
        mouseScroll = MouseScroll(chain: chain, motion: stripMotion)
    }

    func menuWillOpen(_ menu: NSMenu) {
        let granted = Accessibility.isGranted
        permissionItem.title = granted ? "Accessibility: granted" : "Accessibility: not granted"
        openSettingsItem.isHidden = granted
        startMouseScrollIfNeeded()
        refreshChainItems(in: menu)
    }

    private func refreshUpdateIndicators() {
        let icon = NSImage(systemSymbolName: "rectangle.split.3x1", accessibilityDescription: "Window Carousel")
        statusItem.button?.image = updates.release == nil ? icon : icon.map(Self.withUpdateDot)
        updateItem.title = updates.release.map { "Update to \($0.version)…" } ?? ""
        updateItem.isHidden = updates.release == nil
    }

    private static func withUpdateDot(_ icon: NSImage) -> NSImage {
        NSImage(size: icon.size, flipped: false) { rect in
            icon.draw(in: rect)
            NSColor.labelColor.set()
            rect.fill(using: .sourceAtop)
            NSColor.systemOrange.setFill()
            NSBezierPath(ovalIn: NSRect(x: rect.maxX - 6, y: rect.maxY - 6, width: 6, height: 6)).fill()
            return true
        }
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
        startMouseScrollIfNeeded()
        guard let window = Accessibility.focusedWindow() else { return }
        let added = chain.toggle(window)
        guard let area = Screen.usableArea() else { return }
        chain.arrange(in: area, revealingNewest: added)
    }

    private func toggleFullWidthOfFocusedWindow() {
        guard let window = Accessibility.focusedWindow(), let area = Screen.usableArea() else { return }
        chain.toggleFullWidth(window, in: area)
    }

    private func moveFocusedWindow(by step: Int) {
        guard let window = Accessibility.focusedWindow(), let area = Screen.usableArea() else { return }
        chain.move(window, by: step, in: area)
    }

    @objc private func openAccessibilitySettings() {
        Accessibility.openSettings()
    }

    @objc private func showSettings() {
        settingsWindow.show()
    }

    @objc private func showShortcuts() {
        let alert = NSAlert()
        alert.messageText = "Keyboard Shortcuts"
        let shortcuts = NSHostingView(rootView: ShortcutsView())
        shortcuts.frame.size = shortcuts.fittingSize
        alert.accessoryView = shortcuts
        NSApp.activate()
        alert.runModal()
    }
}
