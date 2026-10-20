import Carbon.HIToolbox
import Foundation

@MainActor
final class Hotkey {
    private static var nextID: UInt32 = 1
    private let id: UInt32
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?

    init(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        id = Hotkey.nextID
        Hotkey.nextID += 1
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var pressed = EventHotKeyID()
            GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed
            )
            return MainActor.assumeIsolated {
                let hotkey = Unmanaged<Hotkey>.fromOpaque(userData).takeUnretainedValue()
                guard pressed.id == hotkey.id else { return OSStatus(eventNotHandledErr) }
                hotkey.action()
                return noErr
            }
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)

        let hotKeyID = EventHotKeyID(signature: OSType(0x5743_4152), id: id)
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("Window Carousel: could not register hotkey (status \(status))")
        }
    }
}
