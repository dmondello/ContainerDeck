import SwiftUI
import UniformTypeIdentifiers

/// Sezione Stack: importa un docker-compose.yml e orchestra i servizi
/// sul runtime apple/container (volumi → build → run in ordine).
struct StacksView: View {
    @Environment(AppState.self) private var appState
    @State private var showImporter = false
    @State private var confirmDown = false
    @State private var showLogs = false

    /// ID dei container dei servizi attualmente in esecuzione.
    private var runningServiceContainers: [String] {
        guard let stack = appState.stack else { return [] }
        return stack.services
            .map { $0.containerName(project: stack.name) }
            .filter { id in appState.containers.first { $0.id == id }?.state == .running }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let stack = appState.stack {
                stackHeader(stack)
                Divider()
                servicesList(stack)
                Divider()
                activityLog
            } else {
                EmptyStateView(
                    icon: "square.stack.3d.up",
                    title: L("Nessuno stack caricato"),
                    message: L("Apri un docker-compose.yml per orchestrare più container insieme.")
                )
                if !appState.stackLog.isEmpty {
                    activityLog
                }
            }
        }
        .navigationTitle(L("Stack"))
        .task { appState.restoreLastStack() }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showImporter = true
                } label: {
                    Label(L("Apri compose…"), systemImage: "folder")
                }
                if appState.stack != nil {
                    Button {
                        Task { await appState.stackUp() }
                    } label: {
                        Label(L("Avvia stack"), systemImage: "play.fill")
                    }
                    .disabled(appState.isStackBusy)
                    Button {
                        showLogs = true
                    } label: {
                        Label(L("Log"), systemImage: "doc.text.magnifyingglass")
                    }
                    .disabled(runningServiceContainers.isEmpty)
                    .help(L("Log combinati dei servizi in esecuzione"))
                    Button {
                        Task { await appState.stackStop() }
                    } label: {
                        Label(L("Ferma stack"), systemImage: "stop.fill")
                    }
                    .disabled(appState.isStackBusy)
                    Button {
                        confirmDown = true
                    } label: {
                        Label(L("Rimuovi stack"), systemImage: "trash")
                    }
                    .disabled(appState.isStackBusy)
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.yaml, UTType(filenameExtension: "yml") ?? .data]
        ) { result in
            if case .success(let url) = result {
                appState.loadStack(path: url.path)
            }
        }
        .sheet(isPresented: $showLogs) {
            MultiLogView(containerIDs: runningServiceContainers).environment(appState)
        }
        .confirmationDialog(
            LF("Eliminare i container dello stack “%@”?", appState.stack?.name ?? ""),
            isPresented: $confirmDown
        ) {
            Button(L("Elimina"), role: .destructive) {
                Task { await appState.stackDown() }
            }
        } message: {
            Text(L("I volumi nominati non vengono eliminati."))
        }
    }

    private func stackHeader(_ stack: ComposeStack) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.title2)
                .foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 1) {
                Text(stack.name)
                    .font(.headline)
                Text(stack.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Label(L("Discovery per nome"), systemImage: "network")
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(L("All'avvio i servizi vengono resi raggiungibili per nome via /etc/hosts"))
            if appState.isStackBusy {
                ProgressView().controlSize(.small)
            }
            let running = stack.services.filter { appState.stackServiceState($0) == .running }.count
            Text("\(running)/\(stack.services.count)")
                .font(.callout.monospacedDigit())
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background((running == stack.services.count && running > 0 ? Color.green : .gray).opacity(0.15),
                            in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func servicesList(_ stack: ComposeStack) -> some View {
        Table(stack.services) {
            TableColumn(L("Servizio")) { service in
                Text(service.name).font(.callout.weight(.medium))
            }
            .width(min: 120)

            TableColumn(L("Origine")) { service in
                Text(service.sourceLabel)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(service.sourceLabel)
            }
            .width(min: 200)

            TableColumn(L("Raggiungibile come")) { service in
                Text(service.name)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .help(L("Nome con cui gli altri servizi raggiungono questo container"))
            }
            .width(min: 140)

            TableColumn(L("Stato")) { service in
                if let state = appState.stackServiceState(service) {
                    StatusBadge(state: state)
                } else {
                    Text(L("Non creato"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .width(110)

            TableColumn(L("Porte")) { service in
                Text(service.ports.joined(separator: ", ").nonEmpty ?? "—")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .width(min: 100)
        }
    }

    private var activityLog: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(appState.stackLog.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(index)
                    }
                }
                .padding(10)
            }
            .frame(height: 150)
            .background(.background.secondary)
            .onChange(of: appState.stackLog.count) { _, count in
                guard count > 0 else { return }
                proxy.scrollTo(count - 1, anchor: .bottom)
            }
        }
    }
}
