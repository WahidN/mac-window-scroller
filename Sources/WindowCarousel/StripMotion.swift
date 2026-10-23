import CoreGraphics
import Foundation

@MainActor
final class StripMotion {
    private let chain: WindowChain
    private var velocity: CGFloat = 0
    private var timer: Timer?
    private var lastTick: TimeInterval = 0

    init(chain: WindowChain) {
        self.chain = chain
    }

    func start(velocity: CGFloat) {
        stop()
        self.velocity = velocity
        lastTick = ProcessInfo.processInfo.systemUptime
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        velocity = 0
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = CGFloat(now - lastTick)
        lastTick = now

        let maxOffset = chain.maxOffset
        let offset = chain.offset
        let end = min(max(offset, 0), maxOffset)

        if abs(velocity) >= ScrollPhysics.minimumVelocity {
            let next = ScrollPhysics.momentumStep(offset: offset, velocity: velocity, maxOffset: maxOffset, dt: dt)
            velocity = next.velocity
            chain.show(offset: next.offset)
        } else if offset != end {
            chain.show(offset: ScrollPhysics.springStep(offset: offset, target: end, dt: dt))
        } else {
            stop()
            chain.focusMostVisible()
            chain.fadeOutMiniMap()
        }
    }
}
