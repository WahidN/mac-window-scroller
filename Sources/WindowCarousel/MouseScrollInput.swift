import CoreGraphics

enum MouseScrollInput {
    static func horizontalDelta(flags: CGEventFlags, axis1: CGFloat, axis2: CGFloat) -> CGFloat? {
        guard flags.contains(.maskAlternate) else { return nil }
        if axis2 != 0 { return axis2 }
        // AppKit turns ⇧ + wheel sideways only after the event tap, so the raw event is still vertical.
        if flags.contains(.maskShift), axis1 != 0 { return axis1 }
        return nil
    }
}
