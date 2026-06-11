import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var containerToDelete: DeckContainer?

    private let columns = [GridItem(.adaptive(minimum: 210), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if appState.engineStatus != .running {
                    engineBanner
                }

                if let error = appState.lastError {
                    ErrorBanner(message: error)
                }

                LazyVGrid(columns: columns, spacing: 14) {
                    StatCard(title: L("Container attivi"),
                             value: "\(appState.runningCount)",
                             icon: "play.circle.fill",
                             tint: .green)
                    StatCard(title: L("Container fermi"),
                             value: "\(appState.stoppedCount)",
                             icon: "stop.circle.fill",
                             tint: .gray)
                    StatCard(title: L("CPU complessiva"),
                             value: Format.percent(appState.totalCPUPercent),
                             icon: "cpu",
                             tint: .blue,
                             subtitle: L("somma dei container attivi"))
                    StatCard(title: L("Memoria usata"),
                             value: Format.bytes(appState.totalMemoryBytes),
                             icon: "memorychip",
                             tint: .purple)
                    StatCard(title: L("Spazio su disco"),
                             value: Format.bytes(appState.diskUsageBytes),
                             icon: "internaldrive",
                             tint: .orange,
                             subtitle: L("immagini e container"))
                    StatCard(title: L("Immagini locali"),
                             value: "\(appState.images.count)",
                             icon: "opticaldisc",
                             tint: .teal)
                }

                if !appState.containers.isEmpty {
                    Text(L("Container recenti"))
                        .font(.title3.weight(.semibold))
                        .padding(.top, 6)

                    VStack(spacing: 0) {
                        ForEach(appState.containers.prefix(6)) { container in
                            HStack {
                                StatusBadge(state: container.state)
                                Text(container.id)
                                    .font(.callout.weight(.medium))
                                Text(container.image)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                if let s = appState.stats[container.id] {
                                    Text("\(Format.percent(s.cpuPercent)) · \(Format.bytes(s.memoryBytes))")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                ContainerActionButtons(container: container)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                            .contextMenu {
                                ContainerContextMenuItems(container: container) { containerToDelete = $0 }
                            }
                            if container.id != appState.containers.prefix(6).last?.id {
                                Divider()
                            }
                        }
                    }
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
        }
        .navigationTitle(L("Dashboard"))
        .toolbar { refreshButton }
        .confirmationDialog(
            LF("Eliminare il container “%@”?", containerToDelete?.id ?? ""),
            isPresented: Binding(
                get: { containerToDelete != nil },
                set: { if !$0 { containerToDelete = nil } }
            )
        ) {
            Button(L("Elimina"), role: .destructive) {
                if let container = containerToDelete {
                    Task { await appState.perform(.delete, on: container.id) }
                }
            }
        } message: {
            Text(L("L'operazione non è reversibile."))
        }
    }

    private var engineBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: appState.engineStatus == .notInstalled
                  ? "exclamationmark.triangle.fill" : "pause.circle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.engineStatus.label).font(.headline)
                Text(appState.engineStatus == .notInstalled
                     ? L("Installa apple/container da github.com/apple/container, oppure attiva la Modalità demo nelle Impostazioni.")
                     : L("Avvia il motore per gestire i container."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if appState.engineStatus == .stopped {
                Button(L("Avvia motore")) {
                    Task { await appState.startEngine() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private var refreshButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await appState.refreshAll() }
            } label: {
                if appState.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .help(L("Aggiorna (⌘R)"))
        }
    }
}
