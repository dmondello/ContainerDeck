import Foundation

/// Esegue un comando con privilegi di amministratore tramite il prompt
/// nativo di macOS (osascript `with administrator privileges`).
/// Usato per `container system dns create`, che richiede admin per
/// scrivere in /etc/resolver.
enum PrivilegedRunner {

    struct Cancelled: LocalizedError {
        var errorDescription: String? { "Operazione annullata dall'utente" }
    }

    /// Lancia `command` (già completo di percorso assoluto) con auth admin.
    /// Throwa Cancelled se l'utente chiude il dialogo password.
    static func run(command: String) async throws {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            let errPipe = Pipe()
            process.standardError = errPipe
            process.standardOutput = Pipe()

            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let data = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
                    let message = String(data: data, encoding: .utf8) ?? ""
                    // -128 = utente ha premuto Annulla nel dialogo password.
                    if message.contains("-128") || message.contains("User canceled") {
                        continuation.resume(throwing: Cancelled())
                    } else {
                        continuation.resume(throwing: CLIError(
                            command: command,
                            exitCode: proc.terminationStatus,
                            stderr: message
                        ))
                    }
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
