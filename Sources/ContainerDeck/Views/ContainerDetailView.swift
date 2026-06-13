import SwiftUI

struct ContainerDetailView: View {
    @Environment(AppState.self) private var appState
    let containerID: String

    private enum Tab: String, CaseIterable {
        case overview = "Panoramica"
        case logs = "Log"
        case inspector = "Inspector"

        var title: String { L(rawValue) }
    }

    @State private var tab: Tab = .overview
    @State private var showTerminal = false

    private var container: DeckContainer? {
        appState.containers.first { $0.id == containerID }
    }

    var body: some View {
        Group {
            if let container {
                VStack(spacing: 0) {
                    header(container)
                    Divider()
                    Picker("", selection: $tab) {
                        ForEach(Tab.allCases, id: \.self) { Text($0.title) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(12)

                    switch tab {
                    case .overview: overview(container)
                    case .logs: LogViewer(containerID: container.id)
                    case .inspector: inspector(container)
                    }
                }
            } else {
                EmptyStateView(
                    icon: "shippingbox",
                    title: L("Container non trovato"),
                    message: LF("Il container “%@” non esiste più.", containerID)
                )
            }
        }
        .navigationTitle(containerID)
    }

    private func header(_ container: DeckContainer) -> some View {
        HStack(spacing: 12) {
            StatusBadge(state: container.state)
            Text(container.image)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            ContainerActionButtons(container: container)
            Menu {
                Button {
                    showTerminal = true
                } label: {
                    Label(L("Shell integrata"), systemImage: "terminal")
                }
                Button {
                    TerminalLauncher.run(command: appState.engine.shellCommand(id: container.id))
                } label: {
                    Label(L("Apri in Terminale.app"), systemImage: "macwindow")
                }
            } label: {
                Label("Shell", systemImage: "terminal")
            }
            .menuStyle(.button)
            .disabled(container.state != .running)
            .help(L("Apri una shell nel container"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .sheet(isPresented: $showTerminal) {
            ContainerTerminalSheet(containerID: container.id)
        }
    }

    private func overview(_ container: DeckContainer) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox(L("Configurazione")) {
                    VStack(alignment: .leading, spacing: 6) {
                        InfoRow(label: "ID", value: container.id)
                        InfoRow(label: L("Immagine"), value: container.image)
                        InfoRow(label: L("Piattaforma"), value: "\(container.os ?? "—") / \(container.arch ?? "—")")
                        InfoRow(label: L("CPU assegnate"), value: container.cpus.map(String.init) ?? "—")
                        InfoRow(label: L("Memoria assegnata"), value: Format.bytes(container.memoryBytes))
                        HStack(alignment: .firstTextBaseline) {
                            Text(L("Indirizzi IP"))
                                .foregroundStyle(.secondary)
                                .frame(width: 140, alignment: .leading)
                            if container.addresses.isEmpty {
                                Text("—")
                            } else {
                                ForEach(container.addresses, id: \.self) { address in
                                    IPAddressText(address: address)
                                }
                            }
                            Spacer()
                        }
                        .font(.callout)
                        if let started = container.startedDate {
                            InfoRow(label: L("Avviato"),
                                    value: "\(started.formatted(date: .abbreviated, time: .shortened)) (\(started.formatted(.relative(presentation: .named))))")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                }

                if let stats = appState.stats[container.id] {
                    GroupBox(L("Utilizzo risorse")) {
                        VStack(alignment: .leading, spacing: 6) {
                            InfoRow(label: "CPU", value: Format.percent(stats.cpuPercent))
                            InfoRow(label: L("Memoria"), value: Format.bytes(stats.memoryBytes))
                            if let processes = stats.processCount {
                                InfoRow(label: L("Processi"), value: String(processes))
                            }
                            if stats.networkRxBytes != nil || stats.networkTxBytes != nil {
                                InfoRow(label: L("Rete ↓ / ↑"),
                                        value: "\(Format.bytes(stats.networkRxBytes)) / \(Format.bytes(stats.networkTxBytes))")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                    }
                }

                if !container.mounts.isEmpty {
                    GroupBox(L("Volumi montati")) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(container.mounts, id: \.self) { mount in
                                InfoRow(label: mount.source, value: mount.destination)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                    }
                }

                if !container.env.isEmpty {
                    GroupBox(L("Variabili d'ambiente")) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(container.env, id: \.self) { entry in
                                Text(entry)
                                    .font(.callout.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                    }
                }
            }
            .padding(16)
        }
    }

    private func inspector(_ container: DeckContainer) -> some View {
        ScrollView {
            Text(container.rawJSON)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .background(.background.secondary)
    }
}
