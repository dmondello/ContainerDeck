import SwiftUI
import SwiftTerm

/// Terminale interattivo integrato: connette una `LocalProcessTerminalView`
/// (PTY) al comando `container exec --tty --interactive <id> /bin/sh`,
/// senza handoff a Terminal.app.
struct ContainerTerminal: NSViewRepresentable {
    let executable: String
    let args: [String]

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let view = LocalProcessTerminalView(frame: .zero)
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        let environment = env.map { "\($0.key)=\($0.value)" }
        view.startProcess(executable: executable, args: args, environment: environment)
        return view
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}

/// Sheet che ospita il terminale di un container, con intestazione e chiusura.
/// Alla chiusura il PTY si chiude e la shell riceve SIGHUP, terminando la
/// sessione `exec`.
struct ContainerTerminalSheet: View {
    @Environment(\.dismiss) private var dismiss
    let containerID: String

    private var binaryPath: String { ContainerCLIService.resolveBinaryPath() }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "terminal").foregroundStyle(.teal)
                Text(LF("Shell — %@", containerID)).font(.headline)
                Spacer()
                Text("/bin/sh")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Button(L("Chiudi")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            Divider()
            ContainerTerminal(
                executable: binaryPath,
                args: ["exec", "--tty", "--interactive", containerID, "/bin/sh"]
            )
        }
        .frame(minWidth: 720, minHeight: 440)
    }
}
