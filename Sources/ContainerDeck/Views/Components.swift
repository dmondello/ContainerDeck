import SwiftUI

/// Badge colorato per lo stato di un container.
struct StatusBadge: View {
    let state: ContainerState

    var body: some View {
        Text(state.label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch state {
        case .running: return .green
        case .stopped: return .gray
        case .created: return .blue
        case .paused: return .orange
        case .unknown: return .purple
        }
    }
}

/// Card riepilogativa per la dashboard.
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var tint: Color = .accentColor
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                Spacer()
            }
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.separator.opacity(0.5))
        )
    }
}

/// Riga chiave/valore usata nelle schermate di dettaglio.
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
            Spacer()
        }
        .font(.callout)
    }
}

/// Voci di menu per un indirizzo IP: apertura in browser, VNC
/// (Condivisione Schermo), FTP (Finder) o copia negli appunti.
/// Riusabili sia in un contextMenu sia in un Menu annidato.
struct IPMenuItems: View {
    let address: String

    var body: some View {
        Button {
            open("http://\(address)")
        } label: {
            Label(L("Apri nel browser"), systemImage: "safari")
        }
        Button {
            open("https://\(address)")
        } label: {
            Label(L("Apri nel browser (HTTPS)"), systemImage: "lock")
        }
        Button {
            open("vnc://\(address)")
        } label: {
            Label(L("Apri con VNC"), systemImage: "display")
        }
        Button {
            open("ftp://\(address)")
        } label: {
            Label(L("Apri con FTP"), systemImage: "folder")
        }
        Divider()
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(address, forType: .string)
        } label: {
            Label(L("Copia indirizzo"), systemImage: "doc.on.doc")
        }
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

/// Indirizzo IP con il menu contestuale di IPMenuItems.
struct IPAddressText: View {
    let address: String?

    var body: some View {
        if let address {
            Text(address)
                .monospaced()
                .contextMenu { IPMenuItems(address: address) }
                .help(L("Tasto destro per aprire con browser, VNC o FTP"))
        } else {
            Text("—")
                .monospaced()
                .foregroundStyle(.secondary)
        }
    }
}

/// Menu di gestione completo di un container (ciclo di vita, shell, IP,
/// copia, elimina). Riusato dal menu contestuale della lista container
/// e dalle righe "Container recenti" della dashboard.
struct ContainerContextMenuItems: View {
    @Environment(AppState.self) private var appState
    let container: DeckContainer
    /// L'eliminazione richiede conferma: il chiamante mostra il dialogo.
    let onDelete: (DeckContainer) -> Void

    var body: some View {
        if container.state == .running {
            Button {
                Task { await appState.perform(.stop, on: container.id) }
            } label: {
                Label(L("Ferma"), systemImage: "stop.fill")
            }
            Button {
                Task { await appState.perform(.restart, on: container.id) }
            } label: {
                Label(L("Riavvia"), systemImage: "arrow.clockwise")
            }
            Button {
                TerminalLauncher.run(command: appState.engine.shellCommand(id: container.id))
            } label: {
                Label(L("Apri shell nel Terminale"), systemImage: "terminal")
            }
        } else {
            Button {
                Task { await appState.perform(.start, on: container.id) }
            } label: {
                Label(L("Avvia"), systemImage: "play.fill")
            }
        }

        if let address = container.addresses.first {
            Menu {
                IPMenuItems(address: address)
            } label: {
                Label(LF("Apri %@…", address), systemImage: "network")
            }
        }

        Divider()
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(container.id, forType: .string)
        } label: {
            Label(L("Copia ID"), systemImage: "doc.on.doc")
        }
        Divider()
        Button(role: .destructive) {
            onDelete(container)
        } label: {
            Label(L("Elimina"), systemImage: "trash")
        }
    }
}

/// Banner di errore condiviso. Se l'errore è il kernel di default mancante,
/// mostra la spiegazione e il pulsante di installazione guidata.
struct ErrorBanner: View {
    @Environment(AppState.self) private var appState
    let message: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if appState.lastErrorIsKernelMissing {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(L("Manca il kernel Linux di default (setup iniziale del runtime). Scaricando quello consigliato i container potranno essere avviati."))
                    .font(.callout)
                Spacer()
                Button {
                    Task { await appState.installRecommendedKernel() }
                } label: {
                    if appState.isInstallingKernel {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(L("Installazione…"))
                        }
                    } else {
                        Text(L("Installa kernel"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.isInstallingKernel)
            } else {
                Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                Text(message)
                    .font(.callout)
                    .textSelection(.enabled)
                Spacer()
                Button {
                    appState.lastError = nil
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help(L("Ignora errore"))
            }
        }
        .padding(12)
        .background(
            (appState.lastErrorIsKernelMissing ? Color.orange : Color.red).opacity(0.1),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}

extension View {
    /// Dialogo di conferma distruttiva riusabile, legato a un elemento
    /// opzionale: si presenta quando `item` è non-nil e lo azzera alla
    /// chiusura. Evita di ripetere lo stesso `confirmationDialog` in ogni
    /// vista che elimina qualcosa.
    func deleteConfirmation<Item: Identifiable>(
        _ item: Binding<Item?>,
        title: @escaping (Item) -> String,
        message: String,
        onDelete: @escaping (Item) -> Void
    ) -> some View {
        confirmationDialog(
            item.wrappedValue.map(title) ?? "",
            isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { if !$0 { item.wrappedValue = nil } }
            )
        ) {
            Button(L("Elimina"), role: .destructive) {
                if let value = item.wrappedValue { onDelete(value) }
            }
        } message: {
            Text(message)
        }
    }
}

/// Stato vuoto riusabile per liste senza elementi.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundStyle(.tertiary)
            Text(title).font(.title3.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
