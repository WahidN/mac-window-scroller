import CoreGraphics
import Testing
@testable import WindowCarousel

struct StripLayoutTests {
    let area = CGRect(x: 8, y: 47, width: 1694, height: 1057)
    var view: CGRect { StripLayout.view(in: area) }
    var half: CGFloat { StripLayout.newWindowWidth(viewWidth: view.width) }

    @Test func viewSpansTheUsableArea() {
        #expect(view == area)
        #expect(half == 843)
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

    @Test func mostVisibleWindowWins() {
        let frames = StripLayout.frames(widths: [half, half, half], in: view, offset: 600)

        #expect(StripLayout.mostVisibleIndex(frames: frames, in: view) == 1)
    }

    @Test func leftWindowWinsWhenTwoAreFullyVisible() {
        let frames = StripLayout.frames(widths: [half, half], in: view, offset: 0)

        #expect(StripLayout.mostVisibleIndex(frames: frames, in: view) == 0)
    }

    @Test func halfHiddenWindowLosesToAFullyVisibleOne() {
        let frames = StripLayout.frames(widths: [half, half, half], in: view, offset: half / 2)

        #expect(StripLayout.mostVisibleIndex(frames: frames, in: view) == 1)
    }

    @Test func noWindowsMeansNoFocus() {
        #expect(StripLayout.mostVisibleIndex(frames: [], in: view) == nil)
    }

    @Test func windowsLeftOfTheViewAreParkedOffScreen() {
        let hidden = CGRect(x: -2000, y: area.minY, width: half, height: area.height)
        let parked = StripLayout.parked(hidden, in: view)

        #expect(parked.maxX == view.minX - StripLayout.gap)
        #expect(parked.maxX == area.minX - StripLayout.gap)
    }

    @Test func windowsRightOfTheViewAreParkedOffScreen() {
        let hidden = CGRect(x: 3000, y: area.minY, width: half, height: area.height)
        let parked = StripLayout.parked(hidden, in: view)

        #expect(parked.minX == view.maxX + StripLayout.gap)
        #expect(parked.minX == area.maxX + StripLayout.gap)
    }

    @Test func partlyVisibleWindowsStayWhereTheyAre() {
        let partly = CGRect(x: view.minX - 100, y: area.minY, width: half, height: area.height)

        #expect(StripLayout.parked(partly, in: view) == partly)
    }

    @Test func narrowWindowBecomesFullWidth() {
        #expect(StripLayout.fullWidthToggled(current: half, remembered: nil, viewWidth: view.width) == view.width)
    }

    @Test func narrowWindowBecomesFullWidthEvenWithARememberedWidth() {
        #expect(StripLayout.fullWidthToggled(current: 600, remembered: half, viewWidth: view.width) == view.width)
    }

    @Test func fullWidthWindowGetsItsRememberedWidthBack() {
        #expect(StripLayout.fullWidthToggled(current: view.width, remembered: 500, viewWidth: view.width) == 500)
    }

    @Test func fullWidthWindowWithoutARememberedWidthGetsTheNewWindowWidth() {
        #expect(StripLayout.fullWidthToggled(current: view.width - 1, remembered: nil, viewWidth: view.width) == half)
    }

    @Test func fullWidthWindowFillsTheViewAndPushesItsNeighboursOut() {
        let widths = [half, view.width, half]
        let offset = StripLayout.offset(revealing: 1, widths: widths, viewWidth: view.width, current: 0)
        let frames = StripLayout.frames(widths: widths, in: view, offset: offset)

        #expect(frames[1].minX == view.minX)
        #expect(frames[1].maxX == view.maxX)
        #expect(StripLayout.parked(frames[0], in: view).maxX == view.minX - StripLayout.gap)
        #expect(StripLayout.parked(frames[2], in: view).minX == view.maxX + StripLayout.gap)
    }

    @Test func rightEdgeDragPushesTheWindowsOnTheRight() {
        let before = StripLayout.frames(widths: [half, half, half], in: view, offset: 400)
        let widths = [half, half + 200, half]
        let offset = StripLayout.offset(keeping: 1, atX: before[1].minX, widths: widths, in: view)
        let after = StripLayout.frames(widths: widths, in: view, offset: offset)

        #expect(after[0] == before[0])
        #expect(after[1].minX == before[1].minX)
        #expect(after[2].minX == before[2].minX + 200)
    }

    @Test func leftEdgeDragPushesTheWindowsOnTheLeft() {
        let before = StripLayout.frames(widths: [half, half, half], in: view, offset: 400)
        let widths = [half, half + 200, half]
        let offset = StripLayout.offset(keeping: 1, atX: before[1].minX - 200, widths: widths, in: view)
        let after = StripLayout.frames(widths: widths, in: view, offset: offset)

        #expect(after[0].minX == before[0].minX - 200)
        #expect(after[1].maxX == before[1].maxX)
        #expect(after[2] == before[2])
    }
}
