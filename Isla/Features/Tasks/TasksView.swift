//
//  TasksView.swift
//  Isla
//

import SwiftUI

struct TasksView: View {
    @Bindable var model: NotchViewModel
    private let store = TasksStore.shared
    @State private var draft = ""
    @State private var dueToday = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            IslaCard(padding: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    header
                    if store.tasks.isEmpty {
                        NotchEmptyState(symbol: "checkmark.circle", title: "All clear", message: "Add a task below. It syncs with Reminders when connected.")
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 2) {
                                ForEach(store.tasks) { task in
                                    TaskRow(task: task)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                        .scrollFade()
                    }
                    composer
                }
            }
            sideCard
                .frame(width: 190)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            if store.usesReminders, !store.lists.isEmpty {
                Menu {
                    ForEach(store.lists, id: \.calendarIdentifier) { list in
                        Button(list.title) { store.selectList(list) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle().fill(Color(cgColor: store.currentList?.cgColor ?? CGColor(gray: 0.5, alpha: 1))).frame(width: 8, height: 8)
                        Text(store.currentList?.title ?? String(localized: "Reminders"))
                            .font(.system(size: 13, weight: .bold))
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
            } else {
                Text("Tasks").font(.system(size: 13, weight: .bold))
            }
            Spacer()
            Text("\(store.openCount) open")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
            if store.tasks.contains(where: \.isDone) {
                Button("Clear Done") { store.clearCompleted() }
                    .buttonStyle(NotchPillButtonStyle())
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.accentColor)
            TextField("Add a task", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($focused)
                .onSubmit {
                    store.add(draft, dueToday: dueToday)
                    draft = ""
                }
            Toggle(isOn: $dueToday) {
                Text("Today").font(.system(size: 10.5, weight: .semibold))
            }
            .toggleStyle(.button)
            .buttonStyle(NotchPillButtonStyle(tint: dueToday ? .orange : .white))
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.white.opacity(0.07)))
    }

    private var sideCard: some View {
        IslaCard(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                CardHeader(title: "Today", symbol: "sun.max.fill", tint: .orange)
                let open = store.tasks.filter { !$0.isDone }
                let done = store.tasks.filter(\.isDone)
                let total = max(1, open.count + done.count)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(done.count)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .contentTransition(.numericText(value: Double(done.count)))
                    Text("/ \(open.count + done.count) done")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .animation(IslaMotion.snappy, value: done.count)
                // A slim bar in the notch's own style; empty (no stray dot) when nothing is done.
                GeometryReader { proxy in
                    let share = Double(done.count) / Double(total)
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule()
                            .fill(Color.green.gradient)
                            .frame(width: proxy.size.width * share)
                            .opacity(done.isEmpty ? 0 : 1)
                    }
                    .animation(IslaMotion.content, value: share)
                }
                .frame(height: 5)
                Spacer(minLength: 0)
                if !store.usesReminders {
                    Button("Sync with Reminders") { Task { await store.requestRemindersAccess() } }
                        .buttonStyle(NotchPillButtonStyle())
                } else {
                    Button("Open Reminders") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Reminders.app"))
                    }
                    .buttonStyle(NotchPillButtonStyle())
                }
            }
        }
    }
}

private struct TaskRow: View {
    let task: TaskItem
    private let store = TasksStore.shared

    var body: some View {
        HoverRow(radius: 8) {
            HStack(spacing: 8) {
                Button { store.toggle(task) } label: {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(task.isDone ? Color.green : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                // VoiceOver: the task and whether it is done, not "circle" / "selected".
                .accessibilityLabel(Text(verbatim: task.title))
                .accessibilityValue(task.isDone ? Text("Completed") : Text("Not completed"))
                .accessibilityAddTraits(.isToggle)

                Text(task.title)
                    .font(.system(size: 12))
                    .strikethrough(task.isDone, color: .secondary)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let due = task.due {
                    Text(due, format: Calendar.current.isDateInToday(due) ? .dateTime.hour().minute() : .dateTime.day().month(.abbreviated))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(due < .now && !task.isDone ? Color.red : .secondary)
                }
            }
        }
        .contextMenu {
            Button(task.isDone ? "Mark as Not Done" : "Mark as Done") { store.toggle(task) }
            Button("Delete", role: .destructive) { store.delete(task) }
        }
    }
}
