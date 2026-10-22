import CoreGraphics
import Foundation

private typealias ContactFrameCallback = @convention(c) (
    UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32
) -> Int32
private typealias CreateDeviceList = @convention(c) () -> Unmanaged<CFMutableArray>?
private typealias RegisterContactFrameCallback = @convention(c) (UnsafeMutableRawPointer?, ContactFrameCallback) -> Void
private typealias StartDevice = @convention(c) (UnsafeMutableRawPointer?, Int32) -> Void

private let touchStride = 96
private let normalizedXOffset = 32

private func onContactFrame(
    _ device: UnsafeMutableRawPointer?,
    _ touches: UnsafeMutableRawPointer?,
    _ count: Int32,
    _ timestamp: Double,
    _ frame: Int32
) -> Int32 {
    let fingers = Int(count)
    var centroidX: CGFloat = 0
    if fingers == 3, let touches {
        let xs = (0..<3).map { touches.load(fromByteOffset: $0 * touchStride + normalizedXOffset, as: Float.self) }
        centroidX = CGFloat(xs.reduce(0, +)) / 3
    }
    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            ThreeFingerScroll.current?.handle(fingers: fingers, x: centroidX, time: timestamp)
        }
    }
    return 0
}

@MainActor
final class ThreeFingerScroll {
    private static let pointsPerTrackpadWidth: CGFloat = 1600
    private static let velocityWindow: Double = 0.1
    fileprivate static weak var current: ThreeFingerScroll?

    private let chain: WindowChain
    private let devices: CFMutableArray
    private var lastX: CGFloat?
    private var ignoringSwipe = false
    private var rawOffset: CGFloat = 0
    private var samples: [(time: Double, offset: CGFloat)] = []
    private var velocity: CGFloat = 0
    private var motionTimer: Timer?
    private var lastTick: TimeInterval = 0

    init?(chain: WindowChain) {
        guard let framework = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW),
              let createList = dlsym(framework, "MTDeviceCreateList"),
              let registerCallback = dlsym(framework, "MTRegisterContactFrameCallback"),
              let startDevice = dlsym(framework, "MTDeviceStart"),
              let devices = unsafeBitCast(createList, to: CreateDeviceList.self)()?.takeRetainedValue()
        else {
            NSLog("Window Carousel: MultitouchSupport is not available, three-finger scrolling is off")
            return nil
        }
        self.chain = chain
        self.devices = devices
        Self.current = self

        let register = unsafeBitCast(registerCallback, to: RegisterContactFrameCallback.self)
        let start = unsafeBitCast(startDevice, to: StartDevice.self)
        for index in 0..<CFArrayGetCount(devices) {
            let device = UnsafeMutableRawPointer(mutating: CFArrayGetValueAtIndex(devices, index))
            register(device, onContactFrame)
            start(device, 0)
        }
    }

    fileprivate func handle(fingers: Int, x: CGFloat, time: Double) {
        guard fingers == 3 else {
            if lastX != nil { release(at: time) }
            lastX = nil
            ignoringSwipe = false
            return
        }
        guard !ignoringSwipe else { return }
        guard let previousX = lastX else {
            guard let focused = Accessibility.focusedWindow(), chain.contains(focused) else {
                ignoringSwipe = true
                return
            }
            stopMotion()
            chain.refreshWidths()
            chain.showMiniMap()
            rawOffset = chain.offset
            samples = [(time, chain.offset)]
            lastX = x
            return
        }
        lastX = x
        guard chain.maxOffset > 0 else { return }

        rawOffset -= (x - previousX) * Self.pointsPerTrackpadWidth
        let shown = ScrollPhysics.rubberBanded(rawOffset, maxOffset: chain.maxOffset, dimension: chain.viewWidth)
        chain.show(offset: shown)
        samples.append((time, shown))
        samples.removeAll { time - $0.time > Self.velocityWindow }
    }

    private func release(at time: Double) {
        let recent = samples.filter { time - $0.time <= Self.velocityWindow }
        samples = []
        velocity = 0
        if let first = recent.first, let last = recent.last, last.time > first.time {
            velocity = (last.offset - first.offset) / CGFloat(last.time - first.time)
        }
        startMotion()
    }

    private func startMotion() {
        lastTick = ProcessInfo.processInfo.systemUptime
        motionTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func stopMotion() {
        motionTimer?.invalidate()
        motionTimer = nil
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
            stopMotion()
            chain.focusMostVisible()
            chain.fadeOutMiniMap()
        }
    }
}
