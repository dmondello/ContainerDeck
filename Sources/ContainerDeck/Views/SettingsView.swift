import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @AppStorage(ContainerCLIService.defaultsKey) private var binaryPath = ContainerCLIService.resolveBinaryPath()
    @AppStorage(AppState.pollIntervalKey) private var pollInterval = 5.0
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage(AppState.mockDefaultsKey) private var useMock = false

    @State private var diagnostics = ""
    @State private var runningDiagnostics = false

    private var languageBinding: Binding<String> {
        Binding(
            get: { Localizer.shared.language },
            set: { Localizer.shared.language = $0 }
        )
    }

    var body: some View {
        Form {
            Section(L("Runtime apple/container")) {
                HStack {
                    TextField(L("Percorso CLI"), text: $binaryPath)
                        .font(.callout.monospaced())
                    Button(L("Rileva")) {
                        UserDefaults.standard.removeObject(forKey: ContainerCLIService.defaultsKey)
                        binaryPath = ContainerCLIService.resolveBinaryPath()
                    }
                    .help(L("Cerca il binario nei percorsi standard"))
                }
                LabeledContent(L("Stato motore")) {
                    HStack(spacing: 8) {
                        Text(appState.engineStatus.label)
                        if appState.engineStatus == .running {
                            Button(L("Ferma motore")) {
                                Task { await appState.stopEngine() }
                            }
                        } else if appState.engineStatus == .stopped {
                            Button(L("Avvia motore")) {
                                Task { await appState.startEngine() }
                            }
                        }
                    }
                }
                Toggle(L("Modalità demo (dati di esempio, nessun runtime richiesto)"), isOn: $useMock)
                    .onChange(of: useMock) { _, _ in
                        Task { await appState.refreshAll() }
                    }
            }

            Section(L("Interfaccia")) {
                Picker(L("Lingua"), selection: languageBinding) {
                    Text("Italiano").tag("it")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)

                Picker(L("Tema"), selection: $appearance) {
                    Text(L("Sistema")).tag("system")
                    Text(L("Chiaro")).tag("light")
                    Text(L("Scuro")).tag("dark")
                }
                .pickerStyle(.segmented)

                LabeledContent(L("Aggiornamento dati")) {
                    HStack {
                        Slider(value: $pollInterval, in: 2...30, step: 1)
                            .frame(width: 180)
                        Text("\(Int(pollInterval)) s")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }

            Section(L("Diagnostica")) {
                Button {
                    runDiagnostics()
                } label: {
                    if runningDiagnostics {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(L("Esecuzione…"))
                        }
                    } else {
                        Text(L("Esegui diagnostica"))
                    }
                }
                .disabled(runningDiagnostics)

                if !diagnostics.isEmpty {
                    ScrollView {
                        Text(diagnostics)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 180)
                    .padding(8)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Section(L("Informazioni")) {
                LabeledContent(L("Versione app"), value: "0.6.0")
                LabeledContent(L("Progetto runtime")) {
                    Link("github.com/apple/container",
                         destination: URL(string: "https://github.com/apple/container")!)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L("Impostazioni"))
    }

    private func runDiagnostics() {
        runningDiagnostics = true
        diagnostics = ""
        let path = binaryPath
        Task {
            var report: [String] = []
            report.append("CLI: \(path)")
            report.append("Eseguibile: \(FileManager.default.isExecutableFile(atPath: path) ? "sì" : "NO")")
            for (title, args) in [("system status", ["system", "status"]),
                                  ("system version", ["system", "version"])] {
                do {
                    let output = try await CommandRunner.run(executable: path, arguments: args)
                    report.append("\n$ container \(title)\n\(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                } catch {
                    report.append("\n$ container \(title)\n⚠️ \(error.localizedDescription)")
                }
            }
            diagnostics = report.joined(separator: "\n")
            runningDiagnostics = false
        }
    }
}
