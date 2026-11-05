//
//  AgentsWidget.swift
//  Isla
//
//  The Nook widget: which agents are at work, at a glance. A click opens the AI tab.
//

import SwiftUI

struct AgentsWidgetCard: View {
    let model: NotchViewModel
    private let monitor = AgentMonitor.shared

    var body: some View {
        let sessions = monitor.sessions
        let working = sessions.filter { $0.state == .working }.count

        IslaCard(padding: 11) {
            VStack(alignment: .leading, spacing: 7) {
                CardHeader(title: "Agents", symbol: "sparkles", tint: .orange) {
                    if working > 0 {
                        HStack(spacing: 3) {
                            Circle().fill(AgentState.working.tint).frame(width: 5, height: 5)
                            Text("\(working)")
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText(value: Double(working)))
                        }
                        .foregroundStyle(AgentState.working.tint)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }

                if sessions.isEmpty {
                    Spacer(minLength: 0)
                    VStack(spacing: 5) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(.tertiary)
                        Text("No agents running")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.blurReplace)
                    Spacer(minLength: 0)
                } else {
                    VStack(spacing: 6) {
                        ForEach(sessions.prefix(3)) { session in
                            AgentWidgetRow(session: session)
                                .transition(AnyTransition(.blurReplace).combined(with: .scale(scale: 0.96, anchor: .top)))
                        }
                    }
                    Spacer(minLength: 0)
                    if sessions.count > 3 || !monitor.models.isEmpty {
                        HStack(spacing: 6) {
                            if sessions.count > 3 {
                                Text("+\(sessions.count - 3)")
                            }
                            if !monitor.models.isEmpty {
                                Label {
                                    Text("Models in memory: \(monitor.models.count)")
                                } icon: {
                                    Image(systemName: "cpu")
                                }
                            }
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            model.select(.agents)
            Haptics.tap()
        }
        .animation(IslaMotion.content, value: sessions.map(\.id))
        .animation(IslaMotion.snappy, value: working)
        .onAppear { monitor.refreshNow() }
        .help(String(localized: "Open the AI Tab"))
    }
}

private struct AgentWidgetRow: View {
    let session: AgentSession

    var body: some View {
        HStack(spacing: 7) {
            AgentGlyph(tool: session.tool, icon: AgentMonitor.shared.iconForSession(session), size: 20,
                       working: session.state == .working)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: session.project ?? session.displayTitle)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                TimelineView(.periodic(from: .now, by: 20)) { context in
                    HStack(spacing: 3) {
                        Text(session.state.title)
                            .foregroundStyle(session.state.tint)
                        Text(verbatim: "· " + AgentDuration.label(since: session.stateSince, now: context.date))
                            .foregroundStyle(.tertiary)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if session.state == .working {
                ThinkingDots(tint: session.tool.tint, dot: 3.4)
            }
        }
    }
}
