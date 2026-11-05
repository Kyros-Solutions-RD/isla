//
//  CalendarService.swift
//  Isla
//
//  Reads the calendars you already use on this Mac (iCloud, Google, Exchange…)
//  through EventKit and surfaces upcoming meetings.
//

import EventKit
import SwiftUI

struct AgendaEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    let color: Color
    let calendarTitle: String
    let meetingURL: URL?

    var isHappeningNow: Bool { start <= .now && end > .now }
}

@Observable
@MainActor
final class CalendarService {
    static let shared = CalendarService()

    let store = EKEventStore()
    private(set) var events: [AgendaEvent] = []
    private(set) var calendars: [EKCalendar] = []
    private(set) var authorized = false
    private(set) var now = Date.now

    @ObservationIgnored private var refreshTimer: Timer?
    @ObservationIgnored private var observer: NSObjectProtocol?

    private init() {}

    func start() {
        authorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        if authorized { reload() }
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { _ in
            MainActor.assumeIsolated { CalendarService.shared.reload() }
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            MainActor.assumeIsolated {
                CalendarService.shared.now = .now
                CalendarService.shared.notifyImminentMeetingIfNeeded()
            }
        }
    }

    func requestAccess() async {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        authorized = granted
        if granted { reload() }
    }

    func reload() {
        guard authorized else { return }
        calendars = store.calendars(for: .event).sorted { $0.title < $1.title }
        let hidden = Set(Preferences.shared.hiddenCalendarIDs)
        let visible = calendars.filter { !hidden.contains($0.calendarIdentifier) }
        guard !visible.isEmpty else { events = []; return }

        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 14, to: start) ?? start
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: visible)
        events = store.events(matching: predicate)
            .filter { $0.status != .canceled }
            .map(Self.makeAgendaEvent)
            .sorted { $0.start < $1.start }
        now = .now
    }

    func events(on day: Date) -> [AgendaEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            calendar.isDate(event.start, inSameDayAs: day) ||
            (event.start < day && event.end > calendar.startOfDay(for: day).addingTimeInterval(1))
        }
    }

    var upcoming: [AgendaEvent] {
        events.filter { $0.end > now && !$0.isAllDay }.prefix(6).map { $0 }
    }

    /// A meeting starting within the user's lead time, or in progress for less than 10 minutes.
    var imminentMeeting: AgendaEvent? {
        let lead = TimeInterval(Preferences.shared.meetingLeadMinutes * 60)
        return events.first { event in
            guard !event.isAllDay else { return false }
            let untilStart = event.start.timeIntervalSince(now)
            return (untilStart <= lead && untilStart > -600) && event.end > now
        }
    }

    @ObservationIgnored private var announcedMeetingIDs: Set<String> = []

    private func notifyImminentMeetingIfNeeded() {
        guard Preferences.shared.activityMeetings, let meeting = imminentMeeting,
              !announcedMeetingIDs.contains(meeting.id) else { return }
        announcedMeetingIDs.insert(meeting.id)
        Haptics.tap(.levelChange)
    }

    func toggleCalendar(_ calendar: EKCalendar) {
        var hidden = Preferences.shared.hiddenCalendarIDs
        if let index = hidden.firstIndex(of: calendar.calendarIdentifier) {
            hidden.remove(at: index)
        } else {
            hidden.append(calendar.calendarIdentifier)
        }
        Preferences.shared.hiddenCalendarIDs = hidden
        reload()
    }

    func openInCalendar(_ event: AgendaEvent) {
        let interval = event.start.timeIntervalSinceReferenceDate
        if let url = URL(string: "ical://ekevent/\(event.id)?method=show&options=more") ?? URL(string: "x-apple-calevent://\(interval)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Quick add: "Lunch with Ana" today at the next round hour.
    func addEvent(title: String, start: Date, duration: TimeInterval = 3600) {
        guard authorized, let calendar = store.defaultCalendarForNewEvents else { return }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = start.addingTimeInterval(duration)
        event.calendar = calendar
        try? store.save(event, span: .thisEvent)
        reload()
    }

    #if DEBUG
    func applyDemo() {
        authorized = true
        let now = Date.now
        let today = Calendar.current.startOfDay(for: now)
        func at(_ hour: Int, _ minute: Int, day: Int = 0) -> Date {
            Calendar.current.date(byAdding: DateComponents(day: day, hour: hour, minute: minute), to: today) ?? now
        }
        let zoom = URL(string: "https://zoom.us/j/000000000")
        let meet = URL(string: "https://meet.google.com/isl-anot-chh")
        events = [
            AgendaEvent(id: "d1", title: "Standup del equipo", start: at(9, 30), end: at(9, 45), isAllDay: false, location: nil, color: .blue, calendarTitle: "Trabajo", meetingURL: meet),
            AgendaEvent(id: "d2", title: "Revisión de diseño — Isla", start: now.addingTimeInterval(25 * 60), end: now.addingTimeInterval(85 * 60), isAllDay: false, location: nil, color: .orange, calendarTitle: "Trabajo", meetingURL: zoom),
            AgendaEvent(id: "d3", title: "Almuerzo con Ana", start: now.addingTimeInterval(150 * 60), end: now.addingTimeInterval(210 * 60), isAllDay: false, location: "Zona Colonial", color: .green, calendarTitle: "Personal", meetingURL: nil),
            AgendaEvent(id: "d4", title: "Llamada con cliente", start: now.addingTimeInterval(300 * 60), end: now.addingTimeInterval(330 * 60), isAllDay: false, location: nil, color: .purple, calendarTitle: "Trabajo", meetingURL: meet),
            AgendaEvent(id: "d5", title: "Sprint planning", start: at(10, 0, day: 1), end: at(11, 0, day: 1), isAllDay: false, location: nil, color: .blue, calendarTitle: "Trabajo", meetingURL: zoom),
            AgendaEvent(id: "d6", title: "Lanzamiento de Isla 1.0", start: at(0, 0, day: 3), end: at(23, 59, day: 3), isAllDay: true, location: nil, color: .red, calendarTitle: "Kyros", meetingURL: nil),
        ].sorted { $0.start < $1.start }
        self.now = now
    }
    #endif

    // MARK: Mapping

    private static func makeAgendaEvent(_ event: EKEvent) -> AgendaEvent {
        AgendaEvent(id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title?.nonEmpty ?? String(localized: "Untitled event"),
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    location: event.location?.nonEmpty,
                    color: Color(cgColor: event.calendar.cgColor),
                    calendarTitle: event.calendar.title,
                    meetingURL: meetingLink(for: event))
    }

    private static let meetingHosts = ["zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com", "webex.com",
                                       "whereby.com", "around.co", "facetime.apple.com", "meet.jit.si", "chime.aws", "gotomeeting.com"]

    static func meetingLink(for event: EKEvent) -> URL? {
        if let url = event.url, isMeetingURL(url) { return url }
        let haystack = [event.location, event.notes].compactMap { $0 }.joined(separator: " ")
        guard !haystack.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let matches = detector.matches(in: haystack, range: NSRange(haystack.startIndex..., in: haystack))
        return matches.compactMap(\.url).first(where: isMeetingURL)
    }

    private static func isMeetingURL(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased() else { return false }
        return meetingHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}
