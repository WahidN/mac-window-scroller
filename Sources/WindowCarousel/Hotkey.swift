import Carbon.HIToolbox
import Foundation

@MainActor
final class Hotkey {
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?

    init(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            MainActor.assumeIsolated {
                Unmanaged<Hotkey>.fromOpaque(userData).takeUnretainedValue().action()
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)

        let id = EventHotKeyID(signature: OSType(0x5743_4152), id: 1)
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("Window Carousel: could not register hotkey (status \(status))")
        }
    }
}
