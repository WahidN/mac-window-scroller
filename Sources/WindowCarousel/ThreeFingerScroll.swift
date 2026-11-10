import AppKit

private typealias ContactFrameCallback = @convention(c) (
    UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32
) -> Int32
private typealias CreateDeviceList = @convention(c) () -> Unmanaged<CFMutableArray>?
private typealias RegisterContactFrameCallback = @convention(c) (UnsafeMutableRawPointer?, ContactFrameCallback) -> Void
private typealias StartDevice = @convention(c) (UnsafeMutableRawPointer?, Int32) -> Void
private typealias StopDevice = @convention(c) (UnsafeMutableRawPointer?) -> Void

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
    private let motion: StripMotion
    private let createList: CreateDeviceList
    private let register: RegisterContactFrameCallback
    private let unregister: RegisterContactFrameCallback
    private let startDevice: StartDevice
    private let stopDevice: StopDevice
    private var devices: CFMutableArray?
    private var lastX: CGFloat?
    private var ignoringSwipe = false
    private var rawOffset: CGFloat = 0
    private var samples: [(time: Double, offset: CGFloat)] = []

    init?(chain: WindowChain, motion: StripMotion) {
        guard let framework = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW),
              let createList = dlsym(framework, "MTDeviceCreateList"),
              let registerCallback = dlsym(framework, "MTRegisterContactFrameCallback"),
              let unregisterCallback = dlsym(framework, "MTUnregisterContactFrameCallback"),
              let startDevice = dlsym(framework, "MTDeviceStart"),
              let stopDevice = dlsym(framework, "MTDeviceStop")
        else {
            NSLog("Window Carousel: MultitouchSupport is not available, three-finger scrolling is off")
            return nil
        }
        self.chain = chain
        self.motion = motion
        self.createList = unsafeBitCast(createList, to: CreateDeviceList.self)
        self.register = unsafeBitCast(registerCallback, to: RegisterContactFrameCallback.self)
        self.unregister = unsafeBitCast(unregisterCallback, to: RegisterContactFrameCallback.self)
        self.startDevice = unsafeBitCast(startDevice, to: StartDevice.self)
        self.stopDevice = unsafeBitCast(stopDevice, to: StopDevice.self)
        Self.current = self
        startDevices()
        restartDevicesAfterLockOrSleep()
    }

    private func startDevices() {
        devices = createList()?.takeRetainedValue()
        forEachDevice { device in
            register(device, onContactFrame)
            startDevice(device, 0)
        }
    }

    private func stopDevices() {
        forEachDevice { device in
            unregister(device, onContactFrame)
            stopDevice(device)
        }
        devices = nil
    }

    private func forEachDevice(_ body: (UnsafeMutableRawPointer?) -> Void) {
        guard let devices else { return }
        for index in 0..<CFArrayGetCount(devices) {
            body(UnsafeMutableRawPointer(mutating: CFArrayGetValueAtIndex(devices, index)))
        }
    }

    // macOS reset de trackpad bij lock en sleep, daarna sturen de oude devices niets meer
    private func restartDevicesAfterLockOrSleep() {
        let restart: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stopDevices()
                self?.startDevices()
                self?.lastX = nil
            }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main, using: restart
        )
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: restart)
        workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main, using: restart)
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
            motion.stop()
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
        var velocity: CGFloat = 0
        if let first = recent.first, let last = recent.last, last.time > first.time {
            velocity = (last.offset - first.offset) / CGFloat(last.time - first.time)
        }
        motion.start(velocity: velocity)
    }
}
