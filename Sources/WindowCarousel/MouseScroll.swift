import CoreGraphics
import Foundation

private let phaseBegan: Int64 = 1
private let phaseChanged: Int64 = 2
private let momentumEnded: Int64 = 3

private struct ScrollEvent {
    let flags: CGEventFlags
    let axis1: CGFloat
    let axis2: CGFloat
    let phase: Int64
    let momentumPhase: Int64
}

private func onScrollEvent(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let scroll = ScrollEvent(
        flags: event.flags,
        axis1: CGFloat(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)),
        axis2: CGFloat(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)),
        phase: event.getIntegerValueField(.scrollWheelEventScrollPhase),
        momentumPhase: event.getIntegerValueField(.scrollWheelEventMomentumPhase)
    )
    let taken = MainActor.assumeIsolated {
        MouseScroll.current?.handle(type: type, scroll: scroll) ?? false
    }
    return taken ? nil : Unmanaged.passUnretained(event)
}

@MainActor
final class MouseScroll {
    private static let idleDelay: TimeInterval = 0.15
    fileprivate static weak var current: MouseScroll?

    private let chain: WindowChain
    private let motion: StripMotion
    private let tap: CFMachPort
    private var isScrolling = false
    private var rawOffset: CGFloat = 0
    private var idleTimer: Timer?

    init?(chain: WindowChain, motion: StripMotion) {
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.scrollWheel.rawValue),
            callback: onScrollEvent,
            userInfo: nil
        ) else {
            NSLog("Window Carousel: can't listen to scroll events, mouse scrolling is off")
            return nil
        }
        self.chain = chain
        self.motion = motion
        self.tap = tap
        Self.current = self
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    }

    fileprivate func handle(type: CGEventType, scroll: ScrollEvent) -> Bool {
        guard type == .scrollWheel else {
            CGEvent.tapEnable(tap: tap, enable: true)
            return false
        }
        let flags = isScrolling ? scroll.flags.union(.maskAlternate) : scroll.flags
        let delta = MouseScrollInput.horizontalDelta(flags: flags, axis1: scroll.axis1, axis2: scroll.axis2)

        if !isScrolling {
            guard delta != nil, scroll.momentumPhase == 0, begin() else { return false }
        }
        if let delta {
            rawOffset -= delta
            chain.show(offset: ScrollPhysics.rubberBanded(rawOffset, maxOffset: chain.maxOffset, dimension: chain.viewWidth))
        }

        idleTimer?.invalidate()
        idleTimer = nil
        if scroll.momentumPhase == momentumEnded {
            end()
        } else if scroll.phase != phaseBegan, scroll.phase != phaseChanged {
            idleTimer = Timer.scheduledTimer(withTimeInterval: Self.idleDelay, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.end() }
            }
        }
        return true
    }

    private func begin() -> Bool {
        guard let focused = Accessibility.focusedWindow(), chain.contains(focused) else { return false }
        chain.refreshWidths()
        guard chain.maxOffset > 0 else { return false }
        motion.stop()
        chain.showMiniMap()
        rawOffset = chain.offset
        isScrolling = true
        return true
    }

    private func end() {
        idleTimer?.invalidate()
        idleTimer = nil
        isScrolling = false
        motion.start(velocity: 0)
    }
}
