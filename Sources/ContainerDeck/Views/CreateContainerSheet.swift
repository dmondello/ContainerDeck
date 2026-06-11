import SwiftUI

struct CreateContainerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var spec: NewContainerSpec
    @State private var isCreating = false
    @State private var error: String?
    @State private var isInstallingKernel = false

    /// Primo avvio del runtime: il kernel Linux di default non è configurato.
    private var isKernelError: Bool {
        error?.contains("kernel not configured") == true
            || error?.contains("kernel set") == true
    }

    /// `imageReference` permette di aprire il form già precompilato
    /// (es. dal menu contestuale di un'immagine).
    init(imageReference: String = "") {
        _spec = State(initialValue: NewContainerSpec(image: imageReference))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("Nuovo container"))
                .font(.title2.weight(.semibold))
                .padding(20)

            Form {
                Section(L("Base")) {
                    TextField(L("Nome (opzionale)"), text: $spec.name, prompt: Text(L("es. web-frontend")))
                    TextField(L("Immagine"), text: $spec.image, prompt: Text(L("es. docker.io/library/nginx:latest")))
                    TextField(L("Comando (opzionale)"), text: $spec.command, prompt: Text(L("es. /bin/sh -c \"…\"")))
                }
                Section(L("Risorse")) {
                    TextField(L("CPU (opzionale)"), text: $spec.cpus, prompt: Text(L("es. 2")))
                    TextField(L("Memoria (opzionale)"), text: $spec.memory, prompt: Text(L("es. 512M oppure 2G")))
                }
                Section(L("Rete e storage (una voce per riga)")) {
                    TextField(L("Porte host:container"), text: $spec.ports, prompt: Text("8080:80"), axis: .vertical)
                        .lineLimit(2...4)
                    TextField(L("Variabili CHIAVE=valore"), text: $spec.env, prompt: Text("ENV=production"), axis: .vertical)
                        .lineLimit(2...4)
                    TextField(L("Volumi sorgente:destinazione"), text: $spec.volumes, prompt: Text("dati:/var/lib/data"), axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .formStyle(.grouped)

            if let error {
                VStack(alignment: .leading, spacing: 8) {
                    if isKernelError {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(L("Manca il kernel Linux di default (setup iniziale del runtime). Posso scaricare e configurare quello consigliato, poi riprovare."))
                                .font(.callout)
                            Spacer()
                            Button {
                                installKernelAndRetry()
                            } label: {
                                if isInstallingKernel {
                                    HStack(spacing: 6) {
                                        ProgressView().controlSize(.small)
                                        Text(L("Installazione…"))
                                    }
                                } else {
                                    Text(L("Installa kernel"))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isInstallingKernel)
                        }
                        .padding(10)
                        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    } else {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 20)
            }

            HStack {
                Spacer()
                Button(L("Annulla")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    create()
                } label: {
                    if isCreating {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(L("Crea ed esegui"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(spec.image.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
            }
            .padding(20)
        }
        .frame(width: 520, height: 560)
    }

    private func create() {
        isCreating = true
        error = nil
        Task {
            do {
                try await appState.createContainer(spec)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isCreating = false
        }
    }

    /// Scarica il kernel raccomandato (`container system kernel set
    /// --recommended`) e, a installazione riuscita, ritenta la creazione.
    private func installKernelAndRetry() {
        isInstallingKernel = true
        Task {
            do {
                _ = try await CommandRunner.run(
                    executable: ContainerCLIService.resolveBinaryPath(),
                    arguments: ["system", "kernel", "set", "--recommended"]
                )
                error = nil
                isInstallingKernel = false
                create()
            } catch {
                self.error = error.localizedDescription
                isInstallingKernel = false
            }
        }
    }
}
