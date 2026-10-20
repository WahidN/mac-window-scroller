import CoreGraphics
import Testing
@testable import WindowCarousel

struct StripLayoutTests {
    let area = CGRect(x: 8, y: 47, width: 1694, height: 1057)
    var view: CGRect { StripLayout.view(in: area) }
    var half: CGFloat { StripLayout.newWindowWidth(viewWidth: view.width) }

    @Test func viewLeavesAPeekZoneOnBothSides() {
        #expect(view.minX == 56)
        #expect(view.maxX == 1654)
        #expect(half == 795)
    }

    @Test func twoNewWindowsFillTheView() {
        let frames = StripLayout.frames(widths: [half, half], in: view, offset: 0)

        #expect(frames[0].minX == view.minX)
        #expect(frames[1].minX == frames[0].maxX + StripLayout.gap)
        #expect(frames[1].maxX == view.maxX)
        #expect(frames.allSatisfy { $0.minY == area.minY && $0.height == area.height })
    }

    @Test func thirdWindowIsRevealedAtTheRightEdge() {
        let widths = [half, half, half]
        let offset = StripLayout.offset(revealing: 2, widths: widths, viewWidth: view.width, current: 0)
        let frames = StripLayout.frames(widths: widths, in: view, offset: offset)

        #expect(frames[2].maxX == view.maxX)
        #expect(frames[0].maxX <= view.minX)
    }

    @Test func visibleWindowKeepsTheOffset() {
        let offset = StripLayout.offset(revealing: 1, widths: [half, half], viewWidth: view.width, current: 0)

        #expect(offset == 0)
    }

    @Test func offsetShiftsBackWhenTheStripFits() {
        #expect(StripLayout.clamped(803, widths: [half, half], viewWidth: view.width) == 0)
    }

    @Test func offsetLeavesNoEmptySpaceOnTheRight() {
        let stripWidth = half * 3 + StripLayout.gap * 2

        #expect(StripLayout.clamped(5000, widths: [half, half, half], viewWidth: view.width) == stripWidth - view.width)
    }

    @Test func windowsLeftOfTheViewAreParkedInTheLeftPeekZone() {
        let hidden = CGRect(x: -2000, y: area.minY, width: half, height: area.height)
        let parked = StripLayout.parked(hidden, in: view)

        #expect(parked.maxX == view.minX - StripLayout.gap)
        #expect(parked.maxX == area.minX + StripLayout.peek)
    }

    @Test func windowsRightOfTheViewAreParkedInTheRightPeekZone() {
        let hidden = CGRect(x: 3000, y: area.minY, width: half, height: area.height)
        let parked = StripLayout.parked(hidden, in: view)

        #expect(parked.minX == view.maxX + StripLayout.gap)
        #expect(parked.minX == area.maxX - StripLayout.peek)
    }

    @Test func partlyVisibleWindowsStayWhereTheyAre() {
        let partly = CGRect(x: view.minX - 100, y: area.minY, width: half, height: area.height)

        #expect(StripLayout.parked(partly, in: view) == partly)
    }
}
