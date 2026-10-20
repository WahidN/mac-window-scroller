import ApplicationServices

struct ChainWindow {
    let element: AXUIElement
    let appName: String

    var menuTitle: String {
        let title = stringAttribute(kAXTitleAttribute) ?? ""
        return "\(appName): \(title.isEmpty ? "(no title)" : title)"
    }

    var isClosed: Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .invalidUIElement
    }

    private func stringAttribute(_ attribute: String) -> String? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return value as? String
    }
}

@MainActor
final class WindowChain {
    private(set) var windows: [ChainWindow] = []

    func toggle(_ window: ChainWindow) {
        if let index = windows.firstIndex(where: { CFEqual($0.element, window.element) }) {
            windows.remove(at: index)
        } else {
            windows.append(window)
        }
    }

    func removeClosed() {
        windows.removeAll { $0.isClosed }
    }
}
