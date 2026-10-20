import CoreGraphics

enum MiniMapLayout {
    static let size = CGSize(width: 240, height: 36)
    static let padding: CGFloat = 8
    static let viewportOutset: CGFloat = 3

    static func rects(
        widths: [CGFloat], offset: CGFloat, viewWidth: CGFloat, in size: CGSize
    ) -> (windows: [CGRect], viewport: CGRect) {
        let gap = StripLayout.gap
        let stripWidth = widths.reduce(0, +) + gap * CGFloat(max(widths.count - 1, 0))
        guard stripWidth > 0 else { return ([], .zero) }

        let content = CGRect(origin: .zero, size: size).insetBy(dx: padding, dy: padding)
        let scale = content.width / stripWidth

        var x: CGFloat = 0
        let windows = widths.map { width in
            defer { x += width + gap }
            return CGRect(x: content.minX + x * scale, y: content.minY, width: width * scale, height: content.height)
        }

        let visibleStart = min(max(offset, 0), stripWidth)
        let visibleEnd = min(max(offset + viewWidth, 0), stripWidth)
        let viewport = CGRect(
            x: content.minX + visibleStart * scale,
            y: content.minY - viewportOutset,
            width: (visibleEnd - visibleStart) * scale,
            height: content.height + viewportOutset * 2
        )
        return (windows, viewport)
    }
}
