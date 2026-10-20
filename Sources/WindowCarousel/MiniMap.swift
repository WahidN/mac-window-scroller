import AppKit

@MainActor
final class MiniMap {
    private static let bottomMargin: CGFloat = 16
    private static let fadeInDuration: TimeInterval = 0.15
    private static let fadeOutDuration: TimeInterval = 0.3
    private static let fadeOutDelay: TimeInterval = 1

    private let panel: NSPanel
    private let view = MiniMapView()
    private var fadeGeneration = 0

    init() {
        panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: MiniMapLayout.size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.ignoresCycle]
        panel.alphaValue = 0
        panel.contentView = view
    }

    func update(widths: [CGFloat], offset: CGFloat, viewWidth: CGFloat, focusedIndex: Int?) {
        let layout = MiniMapLayout.rects(widths: widths, offset: offset, viewWidth: viewWidth, in: MiniMapLayout.size)
        view.windows = layout.windows
        view.viewport = layout.viewport
        view.focusedIndex = focusedIndex
        view.needsDisplay = true
    }

    func show() {
        fadeGeneration += 1
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(CGPoint(
                x: visible.midX - MiniMapLayout.size.width / 2,
                y: visible.minY + Self.bottomMargin
            ))
        }
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeInDuration
            panel.animator().alphaValue = 1
        }
    }

    func fadeOutSoon() {
        fadeGeneration += 1
        let generation = fadeGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.fadeOutDelay) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.fadeGeneration == generation else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = Self.fadeOutDuration
                    self.panel.animator().alphaValue = 0
                }
            }
        }
    }
}

private final class MiniMapView: NSView {
    var windows: [CGRect] = []
    var viewport: CGRect = .zero
    var focusedIndex: Int?

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2).fill()

        for (index, block) in windows.enumerated() {
            let color = index == focusedIndex ? NSColor.systemOrange : NSColor.white.withAlphaComponent(0.35)
            color.setFill()
            NSBezierPath(roundedRect: block, xRadius: 3, yRadius: 3).fill()
        }

        guard viewport.width > 0 else { return }
        let frame = NSBezierPath(roundedRect: viewport, xRadius: 4, yRadius: 4)
        frame.lineWidth = 1.5
        NSColor.white.setStroke()
        frame.stroke()
    }
}
