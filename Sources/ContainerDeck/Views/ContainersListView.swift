import SwiftUI

struct ContainersListView: View {
    @Environment(AppState.self) private var appState
    @State private var filter = ""
    @State private var showCreateSheet = false
    @State private var containerToDelete: DeckContainer?
    @State private var showCombinedLogs = false

    private var runningIDs: [String] {
        appState.containers.filter { $0.state == .running }.map(\.id)
    }

    private var filtered: [DeckContainer] {
        guard !filter.isEmpty else { return appState.containers }
        return appState.containers.filter {
            $0.id.localizedCaseInsensitiveContains(filter)
                || $0.image.localizedCaseInsensitiveContains(filter)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let error = appState.lastError {
                ErrorBanner(message: error)
                    .padding(12)
            }
            if appState.containers.isEmpty {
                EmptyStateView(
                    icon: "shippingbox",
                    title: L("Nessun container"),
                    message: L("Crea un container con il pulsante + oppure verifica che il motore sia attivo.")
                )
            } else {
                table
            }
        }
        .navigationTitle(L("Container"))
        .navigationDestination(for: String.self) { id in
            ContainerDetailView(containerID: id)
        }
        .searchable(text: $filter, placement: .toolbar, prompt: L("Filtra per nome o immagine"))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showCombinedLogs = true
                } label: {
                    Label(L("Log combinati"), systemImage: "doc.text.magnifyingglass")
                }
                .disabled(runningIDs.isEmpty)
                .help(L("Log combinati di tutti i container in esecuzione"))
                Button {
                    showCreateSheet = true
                } label: {
                    Label(L("Nuovo container"), systemImage: "plus")
                }
                .help(L("Crea un nuovo container"))
            }
        }
        .sheet(isPresented: $showCombinedLogs) {
            MultiLogView(containerIDs: runningIDs).environment(appState)
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateContainerSheet().environment(appState)
        }
        .deleteConfirmation($containerToDelete,
            title: { LF("Eliminare il container “%@”?", $0.id) },
            message: L("L'operazione non è reversibile.")
        ) { container in
            Task { await appState.perform(.delete, on: container.id) }
        }
    }

    private var table: some View {
        Table(filtered) {
            TableColumn(L("Nome")) { container in
                NavigationLink(value: container.id) {
                    Text(container.id).font(.callout.weight(.medium))
                }
                .buttonStyle(.plain)
            }
            .width(min: 140)

            TableColumn(L("Immagine")) { container in
                Text(container.image)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(container.image)
            }
            .width(min: 180)

            TableColumn(L("Stato")) { container in
                StatusBadge(state: container.state)
            }
            .width(110)

            TableColumn("CPU") { container in
                Text(Format.percent(appState.stats[container.id]?.cpuPercent))
                    .monospacedDigit()
            }
            .width(70)

            TableColumn(L("Memoria")) { container in
                Text(Format.bytes(appState.stats[container.id]?.memoryBytes))
                    .monospacedDigit()
            }
            .width(90)

            TableColumn("IP") { container in
                IPAddressText(address: container.addresses.first)
                    .foregroundStyle(.secondary)
            }
            .width(110)

            TableColumn(L("Azioni")) { container in
                ContainerActionButtons(container: container)
            }
            .width(150)
        }
        .contextMenu(forSelectionType: DeckContainer.ID.self) { ids in
            if let id = ids.first,
               let container = appState.containers.first(where: { $0.id == id }) {
                ContainerContextMenuItems(container: container) { containerToDelete = $0 }
                    .environment(appState)
            }
        }
    }
}

/// Pulsanti rapidi start/stop/restart/delete, riusati in lista e dettaglio.
struct ContainerActionButtons: View {
    @Environment(AppState.self) private var appState
    let container: DeckContainer
    @State private var confirmDelete = false

    private var busy: Bool { appState.busyContainers.contains(container.id) }

    var body: some View {
        HStack(spacing: 4) {
            if container.state == .running {
                actionButton("stop.fill", L("Ferma"), .stop)
                actionButton("arrow.clockwise", L("Riavvia"), .restart)
            } else {
                actionButton("play.fill", L("Avvia"), .start)
            }
            Button {
                confirmDelete = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red.opacity(0.8))
            .disabled(busy)
            .help(L("Elimina"))
            if busy {
                ProgressView().controlSize(.mini)
            }
        }
        .confirmationDialog(
            LF("Eliminare il container “%@”?", container.id),
            isPresented: $confirmDelete
        ) {
            Button(L("Elimina"), role: .destructive) {
                Task { await appState.perform(.delete, on: container.id) }
            }
        } message: {
            Text(L("L'operazione non è reversibile."))
        }
    }

    private func actionButton(_ icon: String, _ help: String, _ action: ContainerAction) -> some View {
        Button {
            Task { await appState.perform(action, on: container.id) }
        } label: {
            Image(systemName: icon)
        }
        .buttonStyle(.borderless)
        .disabled(busy)
        .help(help)
    }
}
