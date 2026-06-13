import SwiftUI

struct ImagesView: View {
    @Environment(AppState.self) private var appState
    @State private var filter = ""
    @State private var showPullSheet = false
    @State private var imageToDelete: DeckImage?
    @State private var imageForNewContainer: DeckImage?

    private var filtered: [DeckImage] {
        guard !filter.isEmpty else { return appState.images }
        return appState.images.filter { $0.reference.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        Group {
            if appState.images.isEmpty {
                EmptyStateView(
                    icon: "opticaldisc",
                    title: L("Nessuna immagine locale"),
                    message: L("Scarica un'immagine da un registry con il pulsante ⤓.")
                )
            } else {
                Table(filtered) {
                    TableColumn(L("Riferimento")) { image in
                        Text(image.name)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                            .help(image.reference)
                    }
                    .width(min: 240)

                    TableColumn("Tag") { image in
                        Text(image.tag)
                            .font(.caption.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.12), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                    .width(90)

                    TableColumn(L("Dimensione")) { image in
                        Text(Format.bytes(image.sizeBytes)).monospacedDigit()
                    }
                    .width(100)

                    TableColumn(L("Creazione")) { image in
                        Text(image.created?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    .width(130)

                    TableColumn("Digest") { image in
                        Text(image.digest?.prefix(19).description ?? "—")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 120)

                    TableColumn("") { image in
                        Button {
                            imageToDelete = image
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red.opacity(0.8))
                        .help(L("Elimina immagine"))
                    }
                    .width(40)
                }
                .contextMenu(forSelectionType: DeckImage.ID.self) { references in
                    if let reference = references.first,
                       let image = appState.images.first(where: { $0.reference == reference }) {
                        Button {
                            imageForNewContainer = image
                        } label: {
                            Label(L("Crea container…"), systemImage: "shippingbox")
                        }
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(image.reference, forType: .string)
                        } label: {
                            Label(L("Copia riferimento"), systemImage: "doc.on.doc")
                        }
                        Divider()
                        Button(role: .destructive) {
                            imageToDelete = image
                        } label: {
                            Label(L("Elimina immagine"), systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(L("Immagini"))
        .searchable(text: $filter, placement: .toolbar, prompt: L("Filtra immagini"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showPullSheet = true
                } label: {
                    Label(L("Scarica immagine"), systemImage: "arrow.down.circle")
                }
            }
        }
        .sheet(isPresented: $showPullSheet) { PullImageSheet().environment(appState) }
        .sheet(item: $imageForNewContainer) { image in
            CreateContainerSheet(imageReference: image.reference).environment(appState)
        }
        .confirmationDialog(
            LF("Eliminare l'immagine “%@”?", imageToDelete?.reference ?? ""),
            isPresented: Binding(
                get: { imageToDelete != nil },
                set: { if !$0 { imageToDelete = nil } }
            )
        ) {
            Button(L("Elimina"), role: .destructive) {
                if let image = imageToDelete {
                    Task { await appState.deleteImage(image.reference) }
                }
            }
        }
    }
}

struct PullImageSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var reference = ""
    @State private var isPulling = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("Scarica immagine"))
                .font(.title2.weight(.semibold))

            TextField(L("Riferimento"), text: $reference,
                      prompt: Text(L("es. docker.io/library/alpine:latest")))
                .textFieldStyle(.roundedBorder)
                .disabled(isPulling)

            Text(L("Vengono supportati i registry OCI compatibili (Docker Hub, GHCR, ECR…)."))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            HStack {
                Spacer()
                Button(L("Annulla")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    pull()
                } label: {
                    if isPulling {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(L("Download…"))
                        }
                    } else {
                        Text(L("Scarica"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(reference.trimmingCharacters(in: .whitespaces).isEmpty || isPulling)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private func pull() {
        isPulling = true
        error = nil
        Task {
            do {
                try await appState.pullImage(reference.trimmingCharacters(in: .whitespaces))
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isPulling = false
        }
    }
}
