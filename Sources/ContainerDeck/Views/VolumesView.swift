import SwiftUI

struct VolumesView: View {
    @Environment(AppState.self) private var appState
    @State private var newVolumeName = ""
    @State private var showCreateAlert = false
    @State private var volumeToDelete: DeckVolume?
    @State private var error: String?

    var body: some View {
        Group {
            if appState.volumes.isEmpty {
                EmptyStateView(
                    icon: "externaldrive",
                    title: L("Nessun volume"),
                    message: L("Crea un volume nominato per persistere i dati dei container.")
                )
            } else {
                Table(appState.volumes) {
                    TableColumn(L("Nome")) { volume in
                        Text(volume.name).font(.callout.weight(.medium))
                    }
                    .width(min: 140)

                    TableColumn(L("Percorso")) { volume in
                        Text(volume.source ?? "—")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .help(volume.source ?? "")
                    }
                    .width(min: 220)

                    TableColumn(L("Dimensione")) { volume in
                        Text(Format.bytes(volume.sizeBytes)).monospacedDigit()
                    }
                    .width(100)

                    TableColumn(L("Usato da")) { volume in
                        let users = appState.containersUsing(volume: volume)
                        Text(users.isEmpty ? "—" : users.map(\.id).joined(separator: ", "))
                            .foregroundStyle(users.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                    }
                    .width(min: 140)

                    TableColumn("") { volume in
                        Button {
                            volumeToDelete = volume
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red.opacity(0.8))
                        .disabled(!appState.containersUsing(volume: volume).isEmpty)
                        .help(appState.containersUsing(volume: volume).isEmpty
                              ? L("Elimina volume")
                              : L("Il volume è in uso da un container"))
                    }
                    .width(40)
                }
            }
        }
        .navigationTitle(L("Volumi"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newVolumeName = ""
                    showCreateAlert = true
                } label: {
                    Label(L("Nuovo volume"), systemImage: "plus")
                }
            }
        }
        .alert(L("Nuovo volume"), isPresented: $showCreateAlert) {
            TextField(L("Nome volume"), text: $newVolumeName)
            Button(L("Crea")) {
                let name = newVolumeName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                Task {
                    do {
                        try await appState.createVolume(name)
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
            Button(L("Annulla"), role: .cancel) {}
        }
        .alert(L("Errore"), isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
        .deleteConfirmation($volumeToDelete,
            title: { LF("Eliminare il volume “%@”?", $0.name) },
            message: L("I dati contenuti nel volume andranno persi.")
        ) { volume in
            Task { await appState.deleteVolume(volume.name) }
        }
    }
}
