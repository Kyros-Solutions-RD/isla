//
//  CalendarView.swift
//  Isla
//

import SwiftUI

struct CalendarView: View {
    @Bindable var model: NotchViewModel
    private let service = CalendarService.shared
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    var body: some View {
        if !service.authorized {
            NotchEmptyState(symbol: "calendar.badge.lock",
                            title: "See your agenda here",
                            message: "Isla reads the calendars already on your Mac — iCloud, Google, Exchange — and never sends them anywhere.",
                            actionTitle: "Allow Calendar Access") {
                Task { await service.requestAccess() }
            }
        } else {
            HStack(spacing: 12) {
                WeekStrip(selectedDay: $selectedDay)
                    .frame(width: 236)
                DayAgenda(day: selectedDay)
            }
        }
    }
}

private struct WeekStrip: View {
    @Binding var selectedDay: Date
    private let service = CalendarService.shared

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days = (0..<14).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }

        IslaCard(padding: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(selectedDay, format: .dateTime.month(.wide).year())
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Button {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .buttonStyle(NotchIconButtonStyle(size: 22))
                    .help(String(localized: "Open Calendar"))
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                    ForEach(days, id: \.self) { day in
                        DayCell(day: day, selected: calendar.isDate(day, inSameDayAs: selectedDay),
                                isToday: calendar.isDate(day, inSameDayAs: today),
                                hasEvents: !service.events(on: day).isEmpty) {
                            withAnimation(IslaMotion.snappy) { selectedDay = day }
                            Haptics.tap()
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct DayCell: View {
    let day: Date
    let selected: Bool
    let isToday: Bool
    let hasEvents: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(day, format: .dateTime.weekday(.narrow))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(selected ? Color.black.opacity(0.6) : Color.secondary)
                Text(day, format: .dateTime.day())
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? Color.black : (isToday ? Color.red : Color.white))
                Circle()
                    .fill(hasEvents ? (selected ? Color.black.opacity(0.5) : Color.white.opacity(0.6)) : .clear)
                    .frame(width: 3.5, height: 3.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Color.white : .clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct DayAgenda: View {
    let day: Date
    private let service = CalendarService.shared
    @State private var newTitle = ""

    var body: some View {
        let events = service.events(on: day)
        IslaCard(padding: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(Calendar.current.isDateInToday(day) ? String(localized: "Today") : day.formatted(.dateTime.weekday(.wide).day().month()))
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Text("\(events.count) events")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                if events.isEmpty {
                    NotchEmptyState(symbol: "sun.max", title: "Nothing scheduled", message: "Enjoy the free time.")
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(events) { event in
                                EventRow(event: event)
                            }
                        }
                    }
                }
                QuickAddField(day: day)
            }
        }
    }
}

private struct EventRow: View {
    let event: AgendaEvent

    var body: some View {
        HoverRow {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(event.color)
                    .frame(width: 3.5)
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(timeLabel)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if let url = event.meetingURL, event.end > .now {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("Join", systemImage: "video.fill")
                    }
                    .buttonStyle(NotchPillButtonStyle(tint: .green))
                } else if event.isHappeningNow {
                    Text("Now")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                }
            }
            .frame(height: 30)
        }
        .onTapGesture(count: 2) { CalendarService.shared.openInCalendar(event) }
    }

    private var timeLabel: String {
        if event.isAllDay { return String(localized: "All day") }
        var label = "\(event.start.shortTime) – \(event.end.shortTime)"
        if let location = event.location, event.meetingURL == nil { label += " · \(location)" }
        return label
    }
}

private struct QuickAddField: View {
    let day: Date
    @State private var title = ""

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            TextField("New event at the next hour", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .onSubmit(add)
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.06)))
    }

    private func add() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let calendar = Calendar.current
        var start = calendar.isDateInToday(day) ? Date.now : calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
        if calendar.isDateInToday(day) {
            start = calendar.nextDate(after: .now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) ?? .now
        }
        CalendarService.shared.addEvent(title: trimmed, start: start)
        title = ""
        Haptics.tap(.levelChange)
    }
}

/// Compact "Up Next" list for the Nook.
struct UpNextCard: View {
    private let service = CalendarService.shared

    var body: some View {
        IslaCard(padding: 11) {
            VStack(alignment: .leading, spacing: 7) {
                CardHeader(title: "Up Next", symbol: "calendar", tint: .red)
                if !service.authorized {
                    Spacer(minLength: 0)
                    Button("Connect Calendar") { Task { await service.requestAccess() } }
                        .buttonStyle(NotchPillButtonStyle())
                    Spacer(minLength: 0)
                } else if service.upcoming.isEmpty {
                    Spacer(minLength: 0)
                    Text("No more events today")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                } else {
                    ForEach(service.upcoming.prefix(3)) { event in
                        HStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 1.5).fill(event.color).frame(width: 3, height: 26)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(event.title)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .lineLimit(1)
                                Text(relative(event))
                                    .font(.system(size: 10))
                                    .foregroundStyle(event.isHappeningNow ? Color.green : .secondary)
                            }
                            Spacer(minLength: 0)
                            if let url = event.meetingURL {
                                Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "video.fill") }
                                    .buttonStyle(NotchIconButtonStyle(size: 22))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func relative(_ event: AgendaEvent) -> String {
        if event.isHappeningNow { return String(localized: "Now · until \(event.end.shortTime)") }
        if Calendar.current.isDateInToday(event.start) { return event.start.shortTime }
        return event.start.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}
