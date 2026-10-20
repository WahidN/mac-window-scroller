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

    var isMinimizedOrFullScreen: Bool {
        boolAttribute(kAXMinimizedAttribute) || boolAttribute("AXFullScreen")
    }

    var size: CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success,
              let value
        else { return nil }
        var size = CGSize.zero
        AXValueGetValue(value as! AXValue, .cgSize, &size)
        return size
    }

    func setSize(_ size: CGSize) {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return }
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }

    func setPosition(_ position: CGPoint) {
        var position = position
        guard let value = AXValueCreate(.cgPoint, &position) else { return }
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    private func stringAttribute(_ attribute: String) -> String? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return value as? String
    }

    private func boolAttribute(_ attribute: String) -> Bool {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return value as? Bool ?? false
    }
}

@MainActor
final class WindowChain {
    private(set) var windows: [ChainWindow] = []
    private(set) var offset: CGFloat = 0
    private var laidOutWindows: [ChainWindow] = []
    private var laidOutWidths: [CGFloat] = []
    private var laidOutView: CGRect = .zero
    private var applyScheduled = false

    func toggle(_ window: ChainWindow) -> Bool {
        if let index = windows.firstIndex(where: { CFEqual($0.element, window.element) }) {
            windows.remove(at: index)
            return false
        }
        windows.append(window)
        return true
    }

    func removeClosed() {
        windows.removeAll { $0.isClosed }
    }

    func arrange(in area: CGRect, revealingNewest: Bool) {
        removeClosed()
        let placed = windows.filter { !$0.isMinimizedOrFullScreen }
        laidOutWindows = []
        guard !placed.isEmpty else { return }

        let view = StripLayout.view(in: area)
        let newWidth = StripLayout.newWindowWidth(viewWidth: view.width)
        for (index, window) in placed.enumerated() {
            let isNewest = revealingNewest && index == placed.count - 1
            let width = isNewest ? newWidth : window.size?.width ?? newWidth
            window.setSize(CGSize(width: width, height: view.height))
        }

        let widths = placed.map { $0.size?.width ?? newWidth }
        offset = revealingNewest
            ? StripLayout.offset(revealing: widths.count - 1, widths: widths, viewWidth: view.width, current: offset)
            : StripLayout.clamped(offset, widths: widths, viewWidth: view.width)

        for (window, frame) in zip(placed, StripLayout.frames(widths: widths, in: view, offset: offset)) {
            let target = StripLayout.parked(frame, in: view)
            window.setPosition(target.origin)
            window.setSize(target.size)
        }

        laidOutWindows = placed
        laidOutWidths = widths
        laidOutView = view
    }

    func scroll(by delta: CGFloat) {
        guard !laidOutWindows.isEmpty else { return }
        offset = StripLayout.clamped(offset + delta, widths: laidOutWidths, viewWidth: laidOutView.width)
        scheduleApply()
    }

    private func scheduleApply() {
        guard !applyScheduled else { return }
        applyScheduled = true
        Task { @MainActor in
            applyScheduled = false
            let frames = StripLayout.frames(widths: laidOutWidths, in: laidOutView, offset: offset)
            for (window, frame) in zip(laidOutWindows, frames) {
                window.setPosition(StripLayout.parked(frame, in: laidOutView).origin)
            }
        }
    }
}
