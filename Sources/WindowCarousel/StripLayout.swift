import CoreGraphics

enum StripLayout {
    static let gap: CGFloat = 8
    static let peek: CGFloat = 40

    static func view(in area: CGRect) -> CGRect {
        area.insetBy(dx: peek + gap, dy: 0)
    }

    static func newWindowWidth(viewWidth: CGFloat) -> CGFloat {
        (viewWidth - gap) / 2
    }

    static func fullWidthToggled(current: CGFloat, remembered: CGFloat?, viewWidth: CGFloat) -> CGFloat {
        guard abs(current - viewWidth) <= 1 else { return viewWidth }
        return remembered ?? newWindowWidth(viewWidth: viewWidth)
    }

    static func frames(widths: [CGFloat], in view: CGRect, offset: CGFloat) -> [CGRect] {
        var x = view.minX - offset
        return widths.map { width in
            defer { x += width + gap }
            return CGRect(x: x, y: view.minY, width: width, height: view.height)
        }
    }

    static func parked(_ frame: CGRect, in view: CGRect) -> CGRect {
        var frame = frame
        if frame.maxX <= view.minX {
            frame.origin.x = view.minX - gap - frame.width
        } else if frame.minX >= view.maxX {
            frame.origin.x = view.maxX + gap
        }
        return frame
    }

    static func mostVisibleIndex(frames: [CGRect], in view: CGRect) -> Int? {
        let visibleWidths = frames.map { max(0, min($0.maxX, view.maxX) - max($0.minX, view.minX)) }
        guard let widest = visibleWidths.max(), widest > 0 else { return nil }
        return visibleWidths.firstIndex(of: widest)
    }

    static func offset(revealing index: Int, widths: [CGFloat], viewWidth: CGFloat, current: CGFloat) -> CGFloat {
        let left = widths[..<index].reduce(0, +) + gap * CGFloat(index)
        let right = left + widths[index]
        if right - current > viewWidth { return right - viewWidth }
        if left < current { return left }
        return current
    }

    static func clamped(_ offset: CGFloat, widths: [CGFloat], viewWidth: CGFloat) -> CGFloat {
        let stripWidth = widths.reduce(0, +) + gap * CGFloat(max(widths.count - 1, 0))
        return max(0, min(offset, stripWidth - viewWidth))
    }
}
