import SwiftUI

/// Visualizzatore log con streaming live (`logs --follow`), filtro testuale
/// e copia negli appunti.
struct LogViewer: View {
    @Environment(AppState.self) private var appState
    let containerID: String

    @State private var lines: [String] = []
    @State private var filter = ""
    @State private var follow = true
    @State private var streamTask: Task<Void, Never>?

    private var filteredLines: [String] {
        guard !filter.isEmpty else { return lines }
        return lines.filter { $0.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            logArea
        }
        .onAppear { startStreaming() }
        .onDisappear { streamTask?.cancel() }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L("Filtra log…"), text: $filter)
                .textFieldStyle(.plain)
                .frame(maxWidth: 260)
            Spacer()
            Toggle(L("Segui"), isOn: $follow)
                .toggleStyle(.checkbox)
                .onChange(of: follow) { _, _ in startStreaming() }
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(filteredLines.joined(separator: "\n"), forType: .string)
            } label: {
                Label(L("Copia"), systemImage: "doc.on.doc")
            }
            .help(L("Copia i log visibili negli appunti"))
            Button {
                lines.removeAll()
            } label: {
                Label(L("Pulisci"), systemImage: "xmark.circle")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var logArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(filteredLines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(index)
                    }
                }
                .padding(10)
            }
            .background(.background.secondary)
            .onChange(of: filteredLines.count) { _, count in
                guard follow, count > 0 else { return }
                proxy.scrollTo(count - 1, anchor: .bottom)
            }
        }
    }

    private func startStreaming() {
        streamTask?.cancel()
        lines.removeAll()
        let engine = appState.engine
        let id = containerID
        let follow = follow
        streamTask = Task {
            do {
                for try await chunk in engine.logs(id: id, follow: follow, lines: 500) {
                    let newLines = chunk.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
                    await MainActor.run {
                        lines.append(contentsOf: newLines)
                        // Tetto di sicurezza per sessioni molto lunghe.
                        if lines.count > 5_000 {
                            lines.removeFirst(lines.count - 5_000)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    lines.append(LF("⚠️ Errore lettura log: %@", error.localizedDescription))
                }
            }
        }
    }
}
