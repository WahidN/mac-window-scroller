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
            ThreeFingerScroll.current?.handle(fingers: fingers, x: centroidX)
        }
    }
    return 0
}

@MainActor
final class ThreeFingerScroll {
    private static let pointsPerTrackpadWidth: CGFloat = 1600
    fileprivate static weak var current: ThreeFingerScroll?

    private let chain: WindowChain
    private let devices: CFMutableArray
    private var lastX: CGFloat?

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

    fileprivate func handle(fingers: Int, x: CGFloat) {
        guard fingers == 3 else {
            lastX = nil
            return
        }
        if let lastX {
            chain.scroll(by: -(x - lastX) * Self.pointsPerTrackpadWidth)
        } else {
            chain.refreshWidths()
        }
        lastX = x
    }
}
