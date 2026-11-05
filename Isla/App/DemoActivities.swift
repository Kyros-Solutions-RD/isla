//
//  DemoActivities.swift
//  Isla
//
//  Debug-only helpers to preview every live activity without real hardware
//  events: `open isla://demo/<name>`.
//

#if DEBUG
import AppKit

@MainActor
enum DemoActivities {
    static func run(_ name: String) {
        let center = LiveActivityCenter.shared
        switch name {
        case "charging": center.post(.power(level: 82, charging: true, pluggedIn: true), duration: 6)
        case "lowbattery": center.post(.lowBattery(level: 9), duration: 6)
        case "airpods": center.post(.device(name: "AirPods Pro", device: .airpodsPro, connected: true, battery: 86), duration: 6)
        case "volume": center.post(.hud(.volume, value: 0.62, muted: false), duration: 6)
        case "brightness": center.post(.hud(.brightness, value: 0.4, muted: false), duration: 6)
        case "caps": center.post(.capsLock(true), duration: 6)
        case "download": center.post(.download(name: "Isla-1.0.dmg", progress: 0.64), duration: 6)
        case "downloaded": center.post(.downloadFinished(name: "Isla-1.0.dmg", url: URL(fileURLWithPath: NSHomeDirectory())), duration: 6)
        case "meeting": center.post(.meeting(title: "Design Review", start: .now.addingTimeInterval(240), url: nil), duration: 6)
        case "timer":
            TimerStore.shared.startTimer(minutes: 25, label: "Focus")
        case "timerdone": center.post(.timerFinished(label: "Tea is ready"), duration: 6)
        case "shelf": center.post(.shelf(count: 3), duration: 6)
        case "track": center.post(.trackChanged, duration: 6)
        case "data":
            NowPlayingService.shared.applyDemo()
            CalendarService.shared.applyDemo()
            WeatherService.shared.applyDemo()
            ClipboardStore.shared.applyDemo()
            TasksStore.shared.applyDemo()
            ShelfStore.shared.applyDemo()
        case "clear":
            for timer in TimerStore.shared.timers { TimerStore.shared.remove(timer) }
            center.dismissTransient()
        default: center.dismissTransient()
        }
    }
}

/// Draws sample album artwork in Isla's sunset palette.
enum DemoArt {
    static func album(size: CGFloat = 600) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let sky = NSGradient(colors: [NSColor(red: 0.98, green: 0.62, blue: 0.4, alpha: 1),
                                          NSColor(red: 0.85, green: 0.27, blue: 0.47, alpha: 1),
                                          NSColor(red: 0.16, green: 0.12, blue: 0.4, alpha: 1)])
            sky?.draw(in: rect, angle: 90)
            NSColor(red: 1, green: 0.88, blue: 0.62, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: rect.midX - rect.width * 0.2, y: rect.height * 0.3, width: rect.width * 0.4, height: rect.width * 0.4)).fill()
            NSColor(red: 0.07, green: 0.09, blue: 0.24, alpha: 1).setFill()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: rect.width, height: rect.height * 0.42)).fill()
            NSColor(red: 1, green: 0.8, blue: 0.6, alpha: 0.55).setFill()
            for index in 0..<4 {
                let width = rect.width * (0.42 - CGFloat(index) * 0.08)
                NSBezierPath(roundedRect: NSRect(x: rect.midX - width / 2, y: rect.height * (0.36 - CGFloat(index) * 0.07), width: width, height: rect.height * 0.018),
                             xRadius: 3, yRadius: 3).fill()
            }
            return true
        }
    }
}
#endif
