import CoreGraphics
import Testing
@testable import WindowCarousel

struct MiniMapLayoutTests {
    let viewWidth: CGFloat = 1598
    let width: CGFloat = 795

    @Test func frameSurroundsTheWindowsOnScreen() {
        let widths = [width, width, width, width]
        let maxOffset = StripLayout.clamped(.infinity, widths: widths, viewWidth: viewWidth)
        let layout = MiniMapLayout.rects(widths: widths, offset: maxOffset, viewWidth: viewWidth, in: MiniMapLayout.size)

        #expect(abs(layout.viewport.minX - layout.windows[2].minX) < 0.01)
        #expect(abs(layout.viewport.maxX - layout.windows[3].maxX) < 0.01)
    }

    @Test func blocksAreInProportionToWindowWidths() {
        let layout = MiniMapLayout.rects(widths: [width, width * 2, width], offset: 0, viewWidth: viewWidth, in: MiniMapLayout.size)

        #expect(abs(layout.windows[1].width - layout.windows[0].width * 2) < 0.01)
    }

    @Test func stripFillsThePillWidth() {
        let layout = MiniMapLayout.rects(widths: [width, width, width], offset: 0, viewWidth: viewWidth, in: MiniMapLayout.size)

        #expect(layout.windows.first?.minX == MiniMapLayout.padding)
        #expect(abs((layout.windows.last?.maxX ?? 0) - (MiniMapLayout.size.width - MiniMapLayout.padding)) < 0.01)
    }

    @Test func frameCoversTheWholeStripWhenTheChainFits() {
        let layout = MiniMapLayout.rects(widths: [width], offset: 0, viewWidth: viewWidth, in: MiniMapLayout.size)

        #expect(layout.viewport.minX == layout.windows[0].minX)
        #expect(abs(layout.viewport.maxX - layout.windows[0].maxX) < 0.01)
    }

    @Test func frameStaysInsideTheStripDuringRubberBand() {
        let layout = MiniMapLayout.rects(widths: [width, width, width], offset: -200, viewWidth: viewWidth, in: MiniMapLayout.size)

        #expect(layout.viewport.minX == layout.windows[0].minX)
    }

    @Test func emptyChainHasNothingToDraw() {
        let layout = MiniMapLayout.rects(widths: [], offset: 0, viewWidth: viewWidth, in: MiniMapLayout.size)

        #expect(layout.windows.isEmpty)
    }
}
