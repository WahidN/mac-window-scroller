import CoreGraphics
import Foundation

enum ScrollPhysics {
    static let rubberBandFactor: CGFloat = 0.55
    static let decelerationPerMillisecond: CGFloat = 0.998
    static let pastEndDecelerationPerMillisecond: CGFloat = 0.95
    static let minimumVelocity: CGFloat = 20
    static let springTimeConstant: CGFloat = 0.07

    static func rubberBanded(_ raw: CGFloat, maxOffset: CGFloat, dimension: CGFloat) -> CGFloat {
        if raw < 0 { return -stretch(-raw, dimension: dimension) }
        if raw > maxOffset { return maxOffset + stretch(raw - maxOffset, dimension: dimension) }
        return raw
    }

    static func momentumStep(
        offset: CGFloat, velocity: CGFloat, maxOffset: CGFloat, dt: CGFloat
    ) -> (offset: CGFloat, velocity: CGFloat) {
        let isPastEnd = offset < 0 || offset > maxOffset
        let rate = isPastEnd ? pastEndDecelerationPerMillisecond : decelerationPerMillisecond
        let newVelocity = velocity * pow(rate, dt * 1000)
        return (offset + newVelocity * dt, newVelocity)
    }

    static func springStep(offset: CGFloat, target: CGFloat, dt: CGFloat) -> CGFloat {
        let remaining = (offset - target) * exp(-dt / springTimeConstant)
        return abs(remaining) < 0.5 ? target : target + remaining
    }

    private static func stretch(_ distance: CGFloat, dimension: CGFloat) -> CGFloat {
        dimension * (1 - 1 / (distance * rubberBandFactor / dimension + 1))
    }
}
