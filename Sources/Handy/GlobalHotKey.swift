import Carbon.HIToolbox

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let identifier: UInt32 = 0x48414E44 // HAND
    private let action: () -> Void

    init(action: @escaping () -> Void) { self.action = action }

    @discardableResult
    func register() -> OSStatus {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            let parameterStatus = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard parameterStatus == noErr else { return parameterStatus }
            let owner = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            if hotKeyID.signature == OSType(owner.identifier), hotKeyID.id == owner.identifier { owner.action() }
            return noErr
        }, 1, &eventType, context, &eventHandler)
        guard installStatus == noErr else { return installStatus }

        let id = EventHotKeyID(signature: OSType(identifier), id: identifier)
        return RegisterEventHotKey(UInt32(kVK_Space), UInt32(optionKey | cmdKey), id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
