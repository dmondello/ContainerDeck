import SwiftUI

struct NetworksView: View {
    @Environment(AppState.self) private var appState
    @State private var newName = ""
    @State private var showCreateAlert = false
    @State private var networkToDelete: DeckNetwork?
    @State private var error: String?

    var body: some View {
        Group {
            if appState.networks.isEmpty {
                EmptyStateView(
                    icon: "network",
                    title: L("Nessuna rete"),
                    message: L("Crea una rete per isolare gruppi di container (richiede macOS 26).")
                )
            } else {
                Table(appState.networks) {
                    TableColumn(L("Nome")) { network in
                        HStack(spacing: 6) {
                            Text(network.id).font(.callout.weight(.medium))
                            if network.isBuiltin {
                                Text(L("predefinita"))
                                    .font(.caption2)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(.gray.opacity(0.15), in: Capsule())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .width(min: 140)

                    TableColumn(L("Modalità")) { network in
                        Text(network.mode ?? "—").foregroundStyle(.secondary)
                    }
                    .width(80)

                    TableColumn(L("Subnet")) { network in
                        Text(network.subnet ?? "—").font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    .width(min: 130)

                    TableColumn(L("Gateway")) { network in
                        Text(network.gateway ?? "—").font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    .width(min: 120)

                    TableColumn(L("Container")) { network in
                        let users = appState.containersOn(network: network)
                        Text(users.isEmpty ? "—" : users.map(\.id).joined(separator: ", "))
                            .foregroundStyle(users.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                    }
                    .width(min: 120)

                    TableColumn("") { network in
                        Button {
                            networkToDelete = network
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red.opacity(0.8))
                        .disabled(network.isBuiltin)
                        .help(network.isBuiltin ? L("La rete predefinita non è eliminabile") : L("Elimina rete"))
                    }
                    .width(40)
                }
            }
        }
        .navigationTitle(L("Reti"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newName = ""
                    showCreateAlert = true
                } label: {
                    Label(L("Nuova rete"), systemImage: "plus")
                }
            }
        }
        .alert(L("Nuova rete"), isPresented: $showCreateAlert) {
            TextField(L("Nome rete"), text: $newName)
            Button(L("Crea")) {
                let name = newName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                Task {
                    do { try await appState.createNetwork(name) }
                    catch { self.error = error.localizedDescription }
                }
            }
            Button(L("Annulla"), role: .cancel) {}
        } message: {
            Text(L("Le reti richiedono macOS 26."))
        }
        .alert(L("Errore"), isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
        .deleteConfirmation($networkToDelete,
            title: { LF("Eliminare la rete “%@”?", $0.id) },
            message: L("L'operazione non è reversibile.")
        ) { network in
            Task { await appState.deleteNetwork(network.id) }
        }
    }
}
