import Testing
@testable import WindowCarousel

struct ChainOrderTests {
    let allPlaced = [true, true, true]

    @Test func moveRightSwapsWithTheNextWindow() {
        #expect(ChainOrder.swapIndex(from: 1, step: 1, isPlaced: allPlaced) == 2)
    }

    @Test func moveLeftSwapsWithThePreviousWindow() {
        #expect(ChainOrder.swapIndex(from: 1, step: -1, isPlaced: allPlaced) == 0)
    }

    @Test func lastWindowCannotMoveRight() {
        #expect(ChainOrder.swapIndex(from: 2, step: 1, isPlaced: allPlaced) == nil)
    }

    @Test func firstWindowCannotMoveLeft() {
        #expect(ChainOrder.swapIndex(from: 0, step: -1, isPlaced: allPlaced) == nil)
    }

    @Test func singleWindowCannotMove() {
        #expect(ChainOrder.swapIndex(from: 0, step: 1, isPlaced: [true]) == nil)
        #expect(ChainOrder.swapIndex(from: 0, step: -1, isPlaced: [true]) == nil)
    }

    @Test func minimizedNeighbourIsSkipped() {
        #expect(ChainOrder.swapIndex(from: 0, step: 1, isPlaced: [true, false, true]) == 2)
    }

    @Test func onlyMinimizedWindowsPastTheEndMeansNoMove() {
        #expect(ChainOrder.swapIndex(from: 1, step: 1, isPlaced: [true, true, false]) == nil)
    }
}
