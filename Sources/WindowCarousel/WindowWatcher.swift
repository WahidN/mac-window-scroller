import ApplicationServices

@MainActor
final class WindowWatcher {
    private let onResize: (AXUIElement) -> Void
    private var observers: [pid_t: AXObserver] = [:]

    init(onResize: @escaping (AXUIElement) -> Void) {
        self.onResize = onResize
    }

    func watch(_ window: ChainWindow) {
        guard let pid = window.pid, let observer = observer(for: pid) else { return }
        AXObserverAddNotification(
            observer, window.element, kAXResizedNotification as CFString, Unmanaged.passUnretained(self).toOpaque()
        )
    }

    func unwatch(_ window: ChainWindow) {
        guard let pid = window.pid, let observer = observers[pid] else { return }
        AXObserverRemoveNotification(observer, window.element, kAXResizedNotification as CFString)
    }

    func keepObservers(for windows: [ChainWindow]) {
        let pids = Set(windows.compactMap(\.pid))
        for (pid, observer) in observers where !pids.contains(pid) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            observers[pid] = nil
        }
    }

    private func observer(for pid: pid_t) -> AXObserver? {
        if let observer = observers[pid] { return observer }
        var created: AXObserver?
        let status = AXObserverCreate(pid, { _, element, _, refcon in
            guard let refcon else { return }
            MainActor.assumeIsolated {
                Unmanaged<WindowWatcher>.fromOpaque(refcon).takeUnretainedValue().onResize(element)
            }
        }, &created)
        guard status == .success, let created else { return nil }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observers[pid] = created
        return created
    }
}
