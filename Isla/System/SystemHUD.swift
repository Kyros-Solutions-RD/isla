//
//  SystemHUD.swift
//  Isla
//
//  Volume and brightness, shown as a slim live activity under the notch. With
//  Accessibility access Isla can also take over the hardware keys and hide
//  the large system overlay.
//

import AppKit
import AudioToolbox
import CoreAudio

// MARK: - Volume

@MainActor
final class SystemAudio {
    static let shared = SystemAudio()

    private(set) var volume: Float = 0.5
    private(set) var isMuted = false

    private var device = AudioObjectID(kAudioObjectUnknown)
    private var listenersInstalled = false
    private var suppressAnnouncementsUntil = Date.distantFuture
    private let volumeSelector: AudioObjectPropertySelector = 0x766D_7663 // 'vmvc' virtual main volume

    private init() {}

    func start() {
        suppressAnnouncementsUntil = .now.addingTimeInterval(1.5)
        refreshDevice()
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main) { _, _ in
            MainActor.assumeIsolated { SystemAudio.shared.refreshDevice() }
        }
    }

    private func refreshDevice() {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        guard id != device else { return }
        device = id
        read()
        installDeviceListeners()
    }

    private func installDeviceListeners() {
        for selector in [volumeSelector, kAudioDevicePropertyMute] {
            var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput,
                                                     mElement: kAudioObjectPropertyElementMain)
            let deviceID = device
            AudioObjectAddPropertyListenerBlock(deviceID, &address, .main) { _, _ in
                MainActor.assumeIsolated {
                    guard SystemAudio.shared.device == deviceID else { return }
                    SystemAudio.shared.read()
                    SystemAudio.shared.announce()
                }
            }
        }
    }

    private func read() {
        var address = AudioObjectPropertyAddress(mSelector: volumeSelector, mScope: kAudioDevicePropertyScopeOutput,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr {
            volume = value
        }
        address.mSelector = kAudioDevicePropertyMute
        var muted: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted) == noErr {
            isMuted = muted != 0
        }
    }

    func announce() {
        guard Date.now > suppressAnnouncementsUntil, Preferences.shared.activityHUD else { return }
        LiveActivityCenter.shared.post(.hud(.volume, value: Double(volume), muted: isMuted), duration: 1.6)
    }

    func setVolume(_ value: Float) {
        var address = AudioObjectPropertyAddress(mSelector: volumeSelector, mScope: kAudioDevicePropertyScopeOutput,
                                                 mElement: kAudioObjectPropertyElementMain)
        var newValue = max(0, min(1, value))
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &newValue)
        volume = newValue
        if isMuted && newValue > 0 { setMuted(false) }
    }

    func setMuted(_ muted: Bool) {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        isMuted = muted
    }

    func step(up: Bool, fine: Bool) {
        let increment: Float = fine ? 1 / 64 : 1 / 16
        let target = ((volume / increment).rounded() + (up ? 1 : -1)) * increment
        setVolume(target)
        suppressAnnouncementsUntil = .distantPast
        LiveActivityCenter.shared.post(.hud(.volume, value: Double(volume), muted: isMuted), duration: 1.6)
    }

    func toggleMute() {
        setMuted(!isMuted)
        LiveActivityCenter.shared.post(.hud(.volume, value: Double(volume), muted: isMuted), duration: 1.6)
    }
}

// MARK: - Brightness

@MainActor
final class DisplayBrightness {
    static let shared = DisplayBrightness()

    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private var getter: GetBrightness?
    private var setter: SetBrightness?

    private init() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) else { return }
        if let symbol = dlsym(handle, "DisplayServicesGetBrightness") { getter = unsafeBitCast(symbol, to: GetBrightness.self) }
        if let symbol = dlsym(handle, "DisplayServicesSetBrightness") { setter = unsafeBitCast(symbol, to: SetBrightness.self) }
    }

    var isAvailable: Bool { getter != nil && setter != nil }

    private var display: CGDirectDisplayID {
        // Prefer the built-in panel, which is the one the brightness keys drive.
        let screens = NSScreen.screens.map(\.displayID)
        return screens.first(where: { CGDisplayIsBuiltin($0) != 0 }) ?? CGMainDisplayID()
    }

    func brightness() -> Float? {
        guard let getter else { return nil }
        var value: Float = 0
        return getter(display, &value) == 0 ? value : nil
    }

    func step(up: Bool, fine: Bool) -> Bool {
        guard let setter, let current = brightness() else { return false }
        let increment: Float = fine ? 1 / 64 : 1 / 16
        let target = max(0, min(1, ((current / increment).rounded() + (up ? 1 : -1)) * increment))
        _ = setter(display, target)
        if Preferences.shared.activityHUD {
            LiveActivityCenter.shared.post(.hud(.brightness, value: Double(target), muted: false), duration: 1.6)
        }
        return true
    }
}

// MARK: - Hardware keys

/// Intercepts the volume and brightness keys when "Replace system HUD" is on.
@MainActor
final class MediaKeyTap {
    static let shared = MediaKeyTap()

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    private init() {}

    var isActive: Bool { tap != nil }

    func update() {
        if Preferences.shared.replaceSystemHUD && AXIsProcessTrusted() {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        guard tap == nil else { return }
        let mask = CGEventMask(1 << 14) // NSEventTypeSystemDefined
        let callback: CGEventTapCallBack = { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                MainActor.assumeIsolated { MediaKeyTap.shared.reenable() }
                return Unmanaged.passUnretained(event)
            }
            let handled = MainActor.assumeIsolated { MediaKeyTap.shared.handle(event) }
            return handled ? nil : Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: callback, userInfo: nil) else { return }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    private func handle(_ event: CGEvent) -> Bool {
        guard event.type.rawValue == 14, let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 else { return false }
        let data = nsEvent.data1
        let keyCode = (data & 0xFFFF_0000) >> 16
        let keyState = (data & 0xFF00) >> 8
        let isDown = keyState == 0x0A
        let fine = nsEvent.modifierFlags.contains(.option) && nsEvent.modifierFlags.contains(.shift)

        switch keyCode {
        case 0, 1: // volume up / down
            if isDown { SystemAudio.shared.step(up: keyCode == 0, fine: fine) }
            return true
        case 7: // mute
            if isDown { SystemAudio.shared.toggleMute() }
            return true
        case 2, 3: // brightness up / down
            guard DisplayBrightness.shared.isAvailable else { return false }
            if isDown { _ = DisplayBrightness.shared.step(up: keyCode == 2, fine: fine) }
            return true
        default:
            return false
        }
    }
}
