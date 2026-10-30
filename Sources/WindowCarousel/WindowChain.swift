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

    var position: CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success,
              let value
        else { return nil }
        var position = CGPoint.zero
        AXValueGetValue(value as! AXValue, .cgPoint, &position)
        return position
    }

    func setSize(_ size: CGSize) {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return }
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }

    var pid: pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(element, &pid) == .success ? pid : nil
    }

    func focus() {
        guard let pid else { return }
        AXUIElementSetAttributeValue(AXUIElementCreateApplication(pid), kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
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
    private var widthsBeforeFullWidth: [AXUIElement: CGFloat] = [:]
    private var applyScheduled = false
    private let focusBorder = FocusBorder()
    private let miniMap = MiniMap()
    private var borderedWindow: ChainWindow?
    private lazy var windowWatcher = WindowWatcher(
        onResize: { [weak self] element in self?.windowResized(element) },
        onClose: { [weak self] in self?.windowClosed() }
    )

    func toggle(_ window: ChainWindow) -> Bool {
        if let index = windows.firstIndex(where: { CFEqual($0.element, window.element) }) {
            windowWatcher.unwatch(windows.remove(at: index))
            windowWatcher.keepObservers(for: windows)
            return false
        }
        windows.append(window)
        windowWatcher.watch(window)
        return true
    }

    private func windowResized(_ element: AXUIElement) {
        guard let index = laidOutWindows.firstIndex(where: { CFEqual($0.element, element) }),
              let width = laidOutWindows[index].size?.width,
              let x = laidOutWindows[index].position?.x,
              abs(width - laidOutWidths[index]) > 1
        else { return }

        laidOutWidths[index] = width
        offset = StripLayout.offset(keeping: index, atX: x, widths: laidOutWidths, in: laidOutView)
        let frames = StripLayout.frames(widths: laidOutWidths, in: laidOutView, offset: offset)
        for (other, (window, frame)) in zip(laidOutWindows, frames).enumerated() where other != index {
            window.setPosition(StripLayout.parked(frame, in: laidOutView).origin)
        }
        refreshBorder()
    }

    private func windowClosed() {
        let count = windows.count
        removeClosed()
        guard windows.count < count else { return }
        place(windows.filter { !$0.isMinimizedOrFullScreen }, in: laidOutView, revealing: nil)
    }

    func removeClosed() {
        windows.removeAll { $0.isClosed }
        windowWatcher.keepObservers(for: windows)
    }

    func arrange(in area: CGRect, revealingNewest: Bool) {
        removeClosed()
        let placed = windows.filter { !$0.isMinimizedOrFullScreen }
        laidOutWindows = []
        guard !placed.isEmpty else {
            refreshBorder()
            return
        }

        let view = StripLayout.view(in: area)
        let newWidth = StripLayout.newWindowWidth(viewWidth: view.width)
        for (index, window) in placed.enumerated() {
            let isNewest = revealingNewest && index == placed.count - 1
            let width = isNewest ? newWidth : window.size?.width ?? newWidth
            window.setSize(CGSize(width: width, height: view.height))
        }

        place(placed, in: view, revealing: revealingNewest ? placed.count - 1 : nil)
    }

    func toggleFullWidth(_ window: ChainWindow, in area: CGRect) {
        removeClosed()
        let placed = windows.filter { !$0.isMinimizedOrFullScreen }
        guard let index = placed.firstIndex(where: { CFEqual($0.element, window.element) }),
              let current = window.size?.width
        else { return }

        let view = StripLayout.view(in: area)
        let width = StripLayout.fullWidthToggled(
            current: current,
            remembered: widthsBeforeFullWidth[window.element],
            viewWidth: view.width
        )
        widthsBeforeFullWidth[window.element] = width == view.width ? current : nil
        // macOS kapt een resize af op de schermrand, dus eerst naar links verplaatsen
        window.setPosition(view.origin)
        window.setSize(CGSize(width: width, height: view.height))
        place(placed, in: view, revealing: index)
    }

    func move(_ window: ChainWindow, by step: Int, in area: CGRect) {
        removeClosed()
        guard let index = windows.firstIndex(where: { CFEqual($0.element, window.element) }),
              let other = ChainOrder.swapIndex(from: index, step: step, isPlaced: windows.map { !$0.isMinimizedOrFullScreen })
        else { return }

        windows.swapAt(index, other)
        let placed = windows.filter { !$0.isMinimizedOrFullScreen }
        place(placed, in: StripLayout.view(in: area), revealing: placed.firstIndex { CFEqual($0.element, window.element) })
    }

    private func place(_ placed: [ChainWindow], in view: CGRect, revealing index: Int?) {
        let newWidth = StripLayout.newWindowWidth(viewWidth: view.width)
        let widths = placed.map { $0.size?.width ?? newWidth }
        offset = index.map { StripLayout.offset(revealing: $0, widths: widths, viewWidth: view.width, current: offset) }
            ?? StripLayout.clamped(offset, widths: widths, viewWidth: view.width)

        for (window, frame) in zip(placed, StripLayout.frames(widths: widths, in: view, offset: offset)) {
            let target = StripLayout.parked(frame, in: view)
            window.setPosition(target.origin)
            window.setSize(target.size)
        }

        laidOutWindows = placed
        laidOutWidths = widths
        laidOutView = view
        refreshBorder()
    }

    func contains(_ window: ChainWindow) -> Bool {
        laidOutWindows.contains { CFEqual($0.element, window.element) }
    }

    func focusMostVisible() {
        let frames = StripLayout.frames(widths: laidOutWidths, in: laidOutView, offset: offset)
        guard let index = StripLayout.mostVisibleIndex(frames: frames, in: laidOutView) else { return }
        let window = laidOutWindows[index]
        window.focus()
        borderedWindow = window
        focusBorder.show(around: StripLayout.parked(frames[index], in: laidOutView), of: window)
        updateMiniMap()
    }

    func showMiniMap() {
        guard !laidOutWindows.isEmpty else { return }
        updateMiniMap()
        miniMap.show()
    }

    func fadeOutMiniMap() {
        miniMap.fadeOutSoon()
    }

    private func updateMiniMap() {
        let focusedIndex = focusBorder.isShowing
            ? laidOutWindows.firstIndex { window in borderedWindow.map { CFEqual($0.element, window.element) } ?? false }
            : nil
        miniMap.update(widths: laidOutWidths, offset: offset, viewWidth: laidOutView.width, focusedIndex: focusedIndex)
    }

    func refreshWidths() {
        laidOutWidths = zip(laidOutWindows, laidOutWidths).map { window, cached in
            window.size?.width ?? cached
        }
    }

    var maxOffset: CGFloat {
        StripLayout.clamped(.infinity, widths: laidOutWidths, viewWidth: laidOutView.width)
    }

    var viewWidth: CGFloat {
        laidOutView.width
    }

    func show(offset newOffset: CGFloat) {
        guard !laidOutWindows.isEmpty else { return }
        offset = newOffset
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
            refreshBorder()
            updateMiniMap()
        }
    }

    private func refreshBorder() {
        guard let bordered = borderedWindow else { return }
        guard let index = laidOutWindows.firstIndex(where: { CFEqual($0.element, bordered.element) }) else {
            borderedWindow = nil
            focusBorder.hide()
            return
        }
        let frames = StripLayout.frames(widths: laidOutWidths, in: laidOutView, offset: offset)
        focusBorder.move(around: StripLayout.parked(frames[index], in: laidOutView))
    }
}
