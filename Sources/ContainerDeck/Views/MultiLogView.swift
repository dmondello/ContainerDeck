import SwiftUI

/// Riga di log aggregata, con il container di origine per color-coding.
private struct MultiLogLine: Identifiable {
    let id: Int
    let container: String
    let colorIndex: Int
    let text: String
}

/// Visualizzatore log multi-container: una sottoscrizione `logs --follow`
/// per container, righe unite in un unico flusso con prefisso colorato,
/// toggle per nascondere singoli container, filtro testo, copia.
struct MultiLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let containerIDs: [String]

    @State private var lines: [MultiLogLine] = []
    @State private var hidden: Set<String> = []
    @State private var filter = ""
    @State private var follow = true
    @State private var counter = 0
    @State private var tasks: [Task<Void, Never>] = []

    private static let palette: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .red, .indigo]

    private func color(_ index: Int) -> Color { Self.palette[index % Self.palette.count] }

    private var visibleLines: [MultiLogLine] {
        lines.filter { line in
            !hidden.contains(line.container)
                && (filter.isEmpty || line.text.localizedCaseInsensitiveContains(filter)
                    || line.container.localizedCaseInsensitiveContains(filter))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            legend
            Divider()
            logArea
        }
        .frame(minWidth: 720, minHeight: 460)
        .onAppear { start() }
        .onDisappear { tasks.forEach { $0.cancel() } }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundStyle(.teal)
            Text(LF("Log combinati (%d container)", containerIDs.count))
                .font(.headline)
            Spacer()
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(L("Filtra log…"), text: $filter)
                .textFieldStyle(.plain)
                .frame(maxWidth: 220)
            Toggle(L("Segui"), isOn: $follow).toggleStyle(.checkbox)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(
                    visibleLines.map { "[\($0.container)] \($0.text)" }.joined(separator: "\n"),
                    forType: .string)
            } label: {
                Label(L("Copia"), systemImage: "doc.on.doc")
            }
            Button(L("Chiudi")) { dismiss() }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// Legenda cliccabile: ogni container col suo colore, click per
    /// mostrare/nascondere le sue righe.
    private var legend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(containerIDs.enumerated()), id: \.offset) { index, id in
                    let isHidden = hidden.contains(id)
                    Button {
                        if isHidden { hidden.remove(id) } else { hidden.insert(id) }
                    } label: {
                        HStack(spacing: 5) {
                            Circle().fill(color(index)).frame(width: 8, height: 8)
                            Text(id).font(.caption.monospaced())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(color(index).opacity(isHidden ? 0.05 : 0.15), in: Capsule())
                        .opacity(isHidden ? 0.45 : 1)
                    }
                    .buttonStyle(.plain)
                    .help(isHidden ? L("Mostra") : L("Nascondi"))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
        }
    }

    private var logArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(visibleLines) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Text(line.container)
                                .font(.caption2.monospaced())
                                .foregroundStyle(color(line.colorIndex))
                                .frame(width: 120, alignment: .leading)
                                .lineLimit(1)
                            Text(line.text)
                                .font(.callout.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .id(line.id)
                    }
                }
                .padding(10)
            }
            .background(.background.secondary)
            .onChange(of: visibleLines.count) { _, _ in
                guard follow, let last = visibleLines.last else { return }
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func start() {
        tasks.forEach { $0.cancel() }
        lines.removeAll()
        let engine = appState.engine
        tasks = containerIDs.enumerated().map { index, id in
            Task {
                do {
                    for try await chunk in engine.logs(id: id, follow: true, lines: 200) {
                        let newLines = chunk.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
                        await MainActor.run {
                            for text in newLines {
                                lines.append(MultiLogLine(id: counter, container: id,
                                                          colorIndex: index, text: text))
                                counter += 1
                            }
                            if lines.count > 8_000 { lines.removeFirst(lines.count - 8_000) }
                        }
                    }
                } catch {
                    await MainActor.run {
                        lines.append(MultiLogLine(id: counter, container: id, colorIndex: index,
                                                  text: LF("⚠️ Errore lettura log: %@", error.localizedDescription)))
                        counter += 1
                    }
                }
            }
        }
    }
}
