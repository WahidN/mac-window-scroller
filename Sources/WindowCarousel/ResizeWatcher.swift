import ApplicationServices

@MainActor
final class ResizeWatcher {
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

    private func observer(for pid: pid_t) -> AXObserver? {
        if let observer = observers[pid] { return observer }
        var created: AXObserver?
        let status = AXObserverCreate(pid, { _, element, _, refcon in
            guard let refcon else { return }
            MainActor.assumeIsolated {
                Unmanaged<ResizeWatcher>.fromOpaque(refcon).takeUnretainedValue().onResize(element)
            }
        }, &created)
        guard status == .success, let created else { return nil }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observers[pid] = created
        return created
    }
}
