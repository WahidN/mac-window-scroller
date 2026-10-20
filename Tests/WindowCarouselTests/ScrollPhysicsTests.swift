import CoreGraphics
import Testing
@testable import WindowCarousel

struct ScrollPhysicsTests {
    let maxOffset: CGFloat = 1000
    let dimension: CGFloat = 1598
    let frame: CGFloat = 1.0 / 60

    @Test func rubberBandLeavesOffsetsInsideTheEndsAlone() {
        #expect(ScrollPhysics.rubberBanded(400, maxOffset: maxOffset, dimension: dimension) == 400)
    }

    @Test func rubberBandStartsAtAboutHalfSpeed() {
        let pastEnd = ScrollPhysics.rubberBanded(maxOffset + 1, maxOffset: maxOffset, dimension: dimension) - maxOffset

        #expect(abs(pastEnd - ScrollPhysics.rubberBandFactor) < 0.01)
    }

    @Test func rubberBandNeverGoesPastOneDimension() {
        #expect(ScrollPhysics.rubberBanded(-1_000_000, maxOffset: maxOffset, dimension: dimension) > -dimension)
        #expect(ScrollPhysics.rubberBanded(1_000_000, maxOffset: maxOffset, dimension: dimension) < maxOffset + dimension)
    }

    @Test func momentumSlowsDownToAStop() {
        var state = (offset: CGFloat(100), velocity: CGFloat(2000))
        for _ in 0..<(60 * 4) {
            let next = ScrollPhysics.momentumStep(offset: state.offset, velocity: state.velocity, maxOffset: 100_000, dt: frame)
            #expect(next.offset > state.offset)
            #expect(next.velocity < state.velocity)
            state = next
        }
        #expect(state.velocity < ScrollPhysics.minimumVelocity)
    }

    @Test func momentumSlowsFasterPastAnEnd() {
        let inside = ScrollPhysics.momentumStep(offset: 500, velocity: 2000, maxOffset: maxOffset, dt: frame)
        let pastEnd = ScrollPhysics.momentumStep(offset: maxOffset + 10, velocity: 2000, maxOffset: maxOffset, dt: frame)

        #expect(pastEnd.velocity < inside.velocity / 2)
    }

    @Test func springReachesTheEndInHalfASecondWithoutOvershoot() {
        var offset: CGFloat = -300
        for _ in 0..<30 {
            offset = ScrollPhysics.springStep(offset: offset, target: 0, dt: frame)
            #expect(offset <= 0)
        }
        #expect(offset == 0)
    }
}
