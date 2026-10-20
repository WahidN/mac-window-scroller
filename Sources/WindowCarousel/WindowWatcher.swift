import ApplicationServices

@MainActor
final class WindowWatcher {
    private static let notifications = [kAXResizedNotification, kAXUIElementDestroyedNotification]

    private let onResize: (AXUIElement) -> Void
    private let onClose: () -> Void
    private var observers: [pid_t: AXObserver] = [:]

    init(onResize: @escaping (AXUIElement) -> Void, onClose: @escaping () -> Void) {
        self.onResize = onResize
        self.onClose = onClose
    }

    func watch(_ window: ChainWindow) {
        guard let pid = window.pid, let observer = observer(for: pid) else { return }
        for notification in Self.notifications {
            AXObserverAddNotification(
                observer, window.element, notification as CFString, Unmanaged.passUnretained(self).toOpaque()
            )
        }
    }

    func unwatch(_ window: ChainWindow) {
        guard let pid = window.pid, let observer = observers[pid] else { return }
        for notification in Self.notifications {
            AXObserverRemoveNotification(observer, window.element, notification as CFString)
        }
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
        let status = AXObserverCreate(pid, { _, element, notification, refcon in
            guard let refcon else { return }
            let isClose = notification as String == kAXUIElementDestroyedNotification
            MainActor.assumeIsolated {
                let watcher = Unmanaged<WindowWatcher>.fromOpaque(refcon).takeUnretainedValue()
                isClose ? watcher.onClose() : watcher.onResize(element)
            }
        }, &created)
        guard status == .success, let created else { return nil }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observers[pid] = created
        return created
    }
}
