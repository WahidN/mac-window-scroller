import CoreGraphics
import Testing
@testable import WindowCarousel

struct MouseScrollInputTests {
    @Test func ignoresScrollWithoutOption() {
        #expect(MouseScrollInput.horizontalDelta(flags: [], axis1: 0, axis2: 12) == nil)
        #expect(MouseScrollInput.horizontalDelta(flags: .maskShift, axis1: 12, axis2: 0) == nil)
    }

    @Test func usesHorizontalAxisWithOption() {
        #expect(MouseScrollInput.horizontalDelta(flags: .maskAlternate, axis1: 3, axis2: -12) == -12)
    }

    @Test func shiftTurnsVerticalWheelSideways() {
        #expect(MouseScrollInput.horizontalDelta(flags: [.maskAlternate, .maskShift], axis1: 10, axis2: 0) == 10)
    }

    @Test func ignoresVerticalScrollWithOptionOnly() {
        #expect(MouseScrollInput.horizontalDelta(flags: .maskAlternate, axis1: 10, axis2: 0) == nil)
    }

    @Test func ignoresEventsWithoutMovement() {
        #expect(MouseScrollInput.horizontalDelta(flags: [.maskAlternate, .maskShift], axis1: 0, axis2: 0) == nil)
    }
}
