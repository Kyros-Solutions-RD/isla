//
//  HotKey.swift
//  Isla
//
//  System-wide keyboard shortcuts through the Carbon hot key API, which needs
//  no special permission.
//

import AppKit
import Carbon.HIToolbox

struct KeyCombo: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var display: String

    static let defaultToggle = KeyCombo(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(controlKey | optionKey), display: "⌃⌥Space")
    static let defaultClipboard = KeyCombo(keyCode: UInt32(kVK_ANSI_V), carbonModifiers: UInt32(controlKey | optionKey), display: "⌃⌥V")
    static let defaultLauncher = KeyCombo(keyCode: UInt32(kVK_ANSI_K), carbonModifiers: UInt32(controlKey | optionKey), display: "⌃⌥K")

    init(keyCode: UInt32, carbonModifiers: UInt32, display: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.display = display
    }

    /// Builds a combo from a key-down event captured by the shortcut recorder.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) || flags.contains(.control) || flags.contains(.option) else { return nil }
        var carbon: UInt32 = 0
        var symbols = ""
        if flags.contains(.control) { carbon |= UInt32(controlKey); symbols += "⌃" }
        if flags.contains(.option) { carbon |= UInt32(optionKey); symbols += "⌥" }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey); symbols += "⇧" }
        if flags.contains(.command) { carbon |= UInt32(cmdKey); symbols += "⌘" }
        self.keyCode = UInt32(event.keyCode)
        self.carbonModifiers = carbon
        self.display = symbols + KeyCombo.keyName(for: event)
    }

    private static func keyName(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            return (event.charactersIgnoringModifiers ?? "?").uppercased()
        }
    }
}

@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    enum Action: UInt32 {
        case toggleNotch = 1
        case clipboard = 2
        case shelf = 3
        case launcher = 4
    }

    private var references: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var handlerInstalled = false

    private init() {}

    func register(_ action: Action, combo: KeyCombo?, handler: @escaping () -> Void) {
        unregister(action)
        guard let combo else { return }
        installHandlerIfNeeded()

        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: OSType(0x49534C41), id: action.rawValue) // "ISLA"
        let status = RegisterEventHotKey(combo.keyCode, combo.carbonModifiers, identifier, GetApplicationEventTarget(), 0, &reference)
        guard status == noErr, let reference else { return }
        references[action.rawValue] = reference
        handlers[action.rawValue] = handler
    }

    func unregister(_ action: Action) {
        if let reference = references.removeValue(forKey: action.rawValue) {
            UnregisterEventHotKey(reference)
        }
        handlers.removeValue(forKey: action.rawValue)
    }

    fileprivate func fire(_ id: UInt32) {
        handlers[id]?()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var identifier = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard status == noErr else { return status }
            let id = identifier.id
            DispatchQueue.main.async { HotKeyCenter.shared.fire(id) }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}
