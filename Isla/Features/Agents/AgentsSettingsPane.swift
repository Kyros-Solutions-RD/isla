//
//  AgentsSettingsPane.swift
//  Isla
//
//  Settings › AI Agents.
//

import SwiftUI

struct AgentsPane: View {
    @Bindable private var prefs = Preferences.shared
    private let monitor = AgentMonitor.shared
    @State private var newCommand = ""

    var body: some View {
        Form {
            Section {
                Toggle("Show the AI tab in the notch", isOn: tabBinding)
                Toggle("Show working agents around the closed notch", isOn: $prefs.activityAgents)
                Toggle("Let me know when an agent finishes or needs me", isOn: $prefs.agentsNotifyFinished)
                Toggle("Show what each agent is doing", isOn: $prefs.agentsShowSteps)
            } header: {
                Text("AI tab")
            } footer: {
                Text("Steps are read from the agent's own session files on this Mac, only while it is working.")
            }

            Section {
                Toggle("Show local models", isOn: $prefs.agentsLocalModels)
            } header: {
                Text("Local models")
            } footer: {
                Text("Isla asks Ollama (port 11434) and LM Studio (port 1234) on this Mac which models are in memory. It never loads or unloads a model.")
            }

            Section {
                ForEach(prefs.agentsCustomCommands, id: \.self) { command in
                    HStack {
                        AgentGlyph(tool: AgentCatalog.custom(command), size: 18)
                        Text(verbatim: command).font(.body.monospaced())
                        Spacer()
                        Button { prefs.agentsCustomCommands.removeAll { $0 == command } } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("Command name", text: $newCommand, prompt: Text(verbatim: "my-agent"))
                        .onSubmit(addCommand)
                    Button("Add", action: addCommand)
                        .disabled(cleanedCommand.isEmpty)
                }
            } header: {
                Text("Other agents")
            } footer: {
                Text("Isla already knows the popular coding agents. Add the command of any other one you run and it shows up while it runs.")
            }

            Section("Detected now") {
                if monitor.sessions.isEmpty && monitor.servers.isEmpty && monitor.apps.isEmpty {
                    Text("Nothing running right now.")
                        .foregroundStyle(.secondary)
                }
                ForEach(monitor.sessions) { session in
                    HStack(spacing: 10) {
                        AgentGlyph(tool: session.tool, icon: monitor.iconForSession(session), size: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: session.displayTitle).lineLimit(1)
                            Text(verbatim: [session.tool.name, session.displayFolder].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Text(session.state.title)
                            .font(.callout)
                            .foregroundStyle(session.state == .working ? Color.green : .secondary)
                    }
                }
                ForEach(monitor.servers) { server in
                    LabeledContent {
                        Text(monitor.models.filter { $0.serverID == server.id }.isEmpty ? "Running" : "Model in memory")
                            .foregroundStyle(.secondary)
                    } label: {
                        Label {
                            Text(verbatim: server.name)
                        } icon: {
                            AgentGlyph(tool: AgentCatalog.tool(id: server.id) ?? AgentCatalog.ollama, size: 18)
                        }
                    }
                }
                if !monitor.apps.isEmpty {
                    LabeledContent("AI apps open") {
                        Text(verbatim: monitor.apps.map(\.name).formatted(.list(type: .and)))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Section {
                Label("No permissions needed: Isla only looks at your own processes and the files agents keep in your home folder.", systemImage: "hand.raised.fill")
                Label("Nothing leaves your Mac.", systemImage: "lock.fill")
                Button("Open the AI Tab") { NotchManager.shared.open(.agents) }
                    .disabled(!prefs.visibleTabs.contains(.agents))
            }
        }
        .onAppear { monitor.refreshNow() }
    }

    private var tabBinding: Binding<Bool> {
        Binding {
            prefs.enabledTabs.contains(.agents)
        } set: { enabled in
            if enabled {
                if !prefs.enabledTabs.contains(.agents) {
                    prefs.enabledTabs.insert(.agents, at: min(1, prefs.enabledTabs.count))
                }
            } else {
                prefs.enabledTabs.removeAll { $0 == .agents }
            }
        }
    }

    private var cleanedCommand: String {
        newCommand.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "/").last?
            .filter { !$0.isWhitespace } ?? ""
    }

    private func addCommand() {
        let command = cleanedCommand
        guard !command.isEmpty, !prefs.agentsCustomCommands.contains(command) else { return }
        prefs.agentsCustomCommands.append(command)
        newCommand = ""
        monitor.refreshNow()
    }
}
