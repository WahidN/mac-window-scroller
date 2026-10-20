import AppKit

enum Screen {
    @MainActor
    static func usableArea() -> CGRect? {
        guard let screen = NSScreen.main, let primary = NSScreen.screens.first else { return nil }
        let visible = screen.visibleFrame
        let flipped = CGRect(
            x: visible.minX,
            y: primary.frame.maxY - visible.maxY,
            width: visible.width,
            height: visible.height
        )
        return flipped.insetBy(dx: StripLayout.gap, dy: StripLayout.gap)
    }
}
