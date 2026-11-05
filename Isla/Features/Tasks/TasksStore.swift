//
//  TasksStore.swift
//  Isla
//
//  Tasks come from Apple Reminders when allowed, otherwise from a private
//  list stored on this Mac.
//

import EventKit
import SwiftUI

struct TaskItem: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var isDone: Bool
    var due: Date?
    var created: Date
}

@Observable
@MainActor
final class TasksStore {
    static let shared = TasksStore()

    private(set) var tasks: [TaskItem] = []
    private(set) var lists: [EKCalendar] = []
    private(set) var usesReminders = false

    @ObservationIgnored private var store: EKEventStore { CalendarService.shared.store }
    @ObservationIgnored private let fileName = "tasks.json"
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var localTasks: [TaskItem] = []

    private init() {
        localTasks = Storage.load([TaskItem].self, from: fileName) ?? []
    }

    var remindersAuthorized: Bool { EKEventStore.authorizationStatus(for: .reminder) == .fullAccess }

    var currentList: EKCalendar? {
        let id = Preferences.shared.remindersListID
        return lists.first { $0.calendarIdentifier == id } ?? store.defaultCalendarForNewReminders()
    }

    var openCount: Int { tasks.filter { !$0.isDone }.count }

    func start() {
        usesReminders = remindersAuthorized
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { TasksStore.shared.reload() }
        }
        reload()
    }

    #if DEBUG
    func applyDemo() {
        usesReminders = false
        let now = Date.now
        localTasks = [
            TaskItem(id: "t1", title: "Publicar Isla 1.0 en GitHub", isDone: false, due: now.addingTimeInterval(3 * 3600), created: now),
            TaskItem(id: "t2", title: "Grabar la demo del notch", isDone: false, due: nil, created: now),
            TaskItem(id: "t3", title: "Responder a Ana sobre el almuerzo", isDone: false, due: nil, created: now.addingTimeInterval(-60)),
            TaskItem(id: "t4", title: "Traducir el sitio al inglés", isDone: true, due: nil, created: now.addingTimeInterval(-7200)),
            TaskItem(id: "t5", title: "Diseñar el ícono", isDone: true, due: nil, created: now.addingTimeInterval(-9000)),
        ]
        tasks = localTasks.sorted(by: Self.order)
    }
    #endif

    func requestRemindersAccess() async {
        let granted = (try? await store.requestFullAccessToReminders()) ?? false
        usesReminders = granted
        reload()
    }

    func useLocalTasks() {
        usesReminders = false
        reload()
    }

    func reload() {
        guard usesReminders else {
            tasks = localTasks.sorted(by: Self.order)
            return
        }
        lists = store.calendars(for: .reminder).sorted { $0.title < $1.title }
        guard let list = currentList else { tasks = []; return }
        let incomplete = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [list])
        let since = Calendar.current.date(byAdding: .day, value: -1, to: .now)
        let completed = store.predicateForCompletedReminders(withCompletionDateStarting: since, ending: nil, calendars: [list])

        Task {
            let open = await fetch(incomplete)
            let done = await fetch(completed)
            self.tasks = (open + done).sorted(by: Self.order)
        }
    }

    private func fetch(_ predicate: NSPredicate) async -> [TaskItem] {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let items = (reminders ?? []).map { reminder in
                    TaskItem(id: reminder.calendarItemIdentifier,
                             title: reminder.title ?? "",
                             isDone: reminder.isCompleted,
                             due: reminder.dueDateComponents?.date,
                             created: reminder.creationDate ?? .now)
                }
                continuation.resume(returning: items)
            }
        }
    }

    private static func order(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.isDone != rhs.isDone { return !lhs.isDone }
        switch (lhs.due, rhs.due) {
        case let (l?, r?): return l < r
        case (_?, nil): return true
        case (nil, _?): return false
        default: return lhs.created > rhs.created
        }
    }

    // MARK: Editing

    func add(_ title: String, dueToday: Bool = false) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let due = dueToday ? Calendar.current.startOfDay(for: .now).addingTimeInterval(17 * 3600) : nil

        if usesReminders, let list = currentList {
            let reminder = EKReminder(eventStore: store)
            reminder.title = trimmed
            reminder.calendar = list
            if let due {
                reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
            }
            try? store.save(reminder, commit: true)
            reload()
        } else {
            localTasks.append(TaskItem(id: UUID().uuidString, title: trimmed, isDone: false, due: due, created: .now))
            saveLocal()
        }
        Haptics.tap(.levelChange)
    }

    func toggle(_ task: TaskItem) {
        if usesReminders {
            if let reminder = store.calendarItem(withIdentifier: task.id) as? EKReminder {
                reminder.isCompleted.toggle()
                try? store.save(reminder, commit: true)
            }
            if let index = tasks.firstIndex(of: task) {
                withAnimation(IslaMotion.content) { tasks[index].isDone.toggle() }
            }
        } else if let index = localTasks.firstIndex(where: { $0.id == task.id }) {
            localTasks[index].isDone.toggle()
            saveLocal()
        }
        Haptics.tap()
    }

    func delete(_ task: TaskItem) {
        if usesReminders {
            if let reminder = store.calendarItem(withIdentifier: task.id) as? EKReminder {
                try? store.remove(reminder, commit: true)
            }
            tasks.removeAll { $0.id == task.id }
        } else {
            localTasks.removeAll { $0.id == task.id }
            saveLocal()
        }
    }

    func clearCompleted() {
        for task in tasks where task.isDone { delete(task) }
    }

    func selectList(_ list: EKCalendar) {
        Preferences.shared.remindersListID = list.calendarIdentifier
        reload()
    }

    private func saveLocal() {
        Storage.save(localTasks, to: fileName)
        withAnimation(IslaMotion.content) { tasks = localTasks.sorted(by: Self.order) }
    }
}
