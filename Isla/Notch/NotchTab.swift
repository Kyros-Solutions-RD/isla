//
//  NotchTab.swift
//  Isla
//

import SwiftUI

enum NotchTab: String, CaseIterable, Identifiable, Codable, Hashable {
    case home
    case shelf
    case clipboard
    case calendar
    case tasks
    case timers
    case notes
    case mirror
    case teleprompter
    case shortcuts
    case terminal

    var id: String { rawValue }

    static let defaultTabs: [NotchTab] = [.home, .shelf, .clipboard, .calendar, .tasks, .timers, .notes, .mirror, .terminal]

    var title: LocalizedStringKey {
        switch self {
        case .home: "Nook"
        case .shelf: "Shelf"
        case .clipboard: "Clipboard"
        case .calendar: "Calendar"
        case .tasks: "Tasks"
        case .timers: "Focus"
        case .notes: "Notes"
        case .mirror: "Mirror"
        case .teleprompter: "Teleprompter"
        case .shortcuts: "Shortcuts"
        case .terminal: "Terminal"
        }
    }

    var titleString: String {
        switch self {
        case .home: String(localized: "Nook")
        case .shelf: String(localized: "Shelf")
        case .clipboard: String(localized: "Clipboard")
        case .calendar: String(localized: "Calendar")
        case .tasks: String(localized: "Tasks")
        case .timers: String(localized: "Focus")
        case .notes: String(localized: "Notes")
        case .mirror: String(localized: "Mirror")
        case .teleprompter: String(localized: "Teleprompter")
        case .shortcuts: String(localized: "Shortcuts")
        case .terminal: String(localized: "Terminal")
        }
    }

    var symbol: String {
        switch self {
        case .home: "square.grid.2x2.fill"
        case .shelf: "tray.full.fill"
        case .clipboard: "doc.on.clipboard.fill"
        case .calendar: "calendar"
        case .tasks: "checklist"
        case .timers: "timer"
        case .notes: "note.text"
        case .mirror: "person.crop.square.fill"
        case .teleprompter: "text.alignleft"
        case .shortcuts: "square.stack.3d.up.fill"
        case .terminal: "apple.terminal.fill"
        }
    }

    var summary: LocalizedStringKey {
        switch self {
        case .home: "Your widgets: music, up next, weather and more."
        case .shelf: "Drop files to hold them, then drag them anywhere or AirDrop them."
        case .clipboard: "Everything you copied, searchable. Passwords are never saved."
        case .calendar: "Your agenda for the week with one-click meeting links."
        case .tasks: "Quick tasks synced with Reminders."
        case .timers: "Pomodoro, timers and focus sounds."
        case .notes: "Quick notes that stay on your Mac."
        case .mirror: "Check your camera before a call."
        case .teleprompter: "Read scripts right under your camera, at your pace or following your voice."
        case .shortcuts: "Run your favorite Shortcuts from the notch."
        case .terminal: "A real shell under the notch that keeps running in the background."
        }
    }
}
