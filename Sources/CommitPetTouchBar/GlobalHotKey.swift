import Carbon
import Foundation

private let booHotKeySignature: OSType = 0x424F4F31 // "BOO1"
private let booHotKeyID: UInt32 = 1

private let booHotKeyEventHandler: EventHandlerUPP = { _, event, _ in
    guard let event else { return OSStatus(eventNotHandledErr) }
    var identifier = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &identifier
    )
    guard status == noErr,
          identifier.signature == booHotKeySignature,
          identifier.id == booHotKeyID else {
        return OSStatus(eventNotHandledErr)
    }
    NotificationCenter.default.post(name: .toggleDesktopBooHotKey, object: nil)
    return noErr
}

final class GlobalHotKey {
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    /// Registers Control-Option-B without requiring Accessibility permission.
    func register() -> Bool {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            booHotKeyEventHandler,
            1,
            &eventType,
            nil,
            &eventHandler
        )
        guard handlerStatus == noErr else { return false }

        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: booHotKeySignature, id: booHotKeyID)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_B),
            UInt32(controlKey | optionKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard registerStatus == noErr else {
            unregister()
            return false
        }
        hotKey = reference
        return true
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    deinit {
        unregister()
    }
}

extension Notification.Name {
    static let toggleDesktopBooHotKey = Notification.Name("ToggleDesktopBooHotKey")
}
