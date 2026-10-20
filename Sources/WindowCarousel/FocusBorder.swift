import AppKit
import ApplicationServices

@MainActor
final class FocusBorder {
    private static let lineWidth: CGFloat = 3
    private static let outset: CGFloat = 2
    private static let cornerRadius: CGFloat = 12

    private let panel: NSPanel
    private var ownerPID: pid_t?
    private var closeObserver: AXObserver?
    private var activationObserver: NSObjectProtocol?

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.ignoresCycle]
        panel.contentView = BorderView(lineWidth: Self.lineWidth, cornerRadius: Self.cornerRadius)

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let pid = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            MainActor.assumeIsolated {
                guard let self, pid != self.ownerPID else { return }
                self.hide()
            }
        }
    }

    var isShowing: Bool {
        ownerPID != nil
    }

    func show(around frame: CGRect, of window: ChainWindow) {
        hide()
        guard let pid = window.pid else { return }
        ownerPID = pid
        observeClose(of: window, pid: pid)
        move(around: frame)
        panel.orderFrontRegardless()
    }

    func move(around frame: CGRect) {
        guard ownerPID != nil, let primary = NSScreen.screens.first else { return }
        let appKitFrame = CGRect(
            x: frame.minX,
            y: primary.frame.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
        let margin = Self.outset + Self.lineWidth
        panel.setFrame(appKitFrame.insetBy(dx: -margin, dy: -margin), display: true)
    }

    func hide() {
        panel.orderOut(nil)
        ownerPID = nil
        if let closeObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(closeObserver), .defaultMode)
        }
        closeObserver = nil
    }

    private func observeClose(of window: ChainWindow, pid: pid_t) {
        var observer: AXObserver?
        let created = AXObserverCreate(pid, { _, _, _, refcon in
            guard let refcon else { return }
            MainActor.assumeIsolated {
                Unmanaged<FocusBorder>.fromOpaque(refcon).takeUnretainedValue().hide()
            }
        }, &observer)
        guard created == .success, let observer else { return }
        AXObserverAddNotification(
            observer, window.element, kAXUIElementDestroyedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque()
        )
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        closeObserver = observer
    }
}

private final class BorderView: NSView {
    private let lineWidth: CGFloat
    private let cornerRadius: CGFloat

    init(lineWidth: CGFloat, cornerRadius: CGFloat) {
        self.lineWidth = lineWidth
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2),
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )
        path.lineWidth = lineWidth
        NSColor.systemOrange.setStroke()
        path.stroke()
    }
}
