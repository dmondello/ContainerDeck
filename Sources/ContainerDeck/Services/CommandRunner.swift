import Foundation

struct CLIError: LocalizedError {
    let command: String
    let exitCode: Int32
    let stderr: String

    var errorDescription: String? {
        let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return "`\(command)` terminato con codice \(exitCode)"
            + (detail.isEmpty ? "" : ": \(detail)")
    }
}

/// Esecuzione asincrona di processi esterni, con cattura completa di
/// stdout/stderr e variante streaming per log e statistiche live.
enum CommandRunner {

    static func run(executable: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            // Lettura incrementale: evita il deadlock da buffer pieno
            // che si avrebbe leggendo tutto solo a processo terminato.
            let collector = DataCollector()
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                collector.appendOut(handle.availableData)
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                collector.appendErr(handle.availableData)
            }

            process.terminationHandler = { proc in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                if let rest = try? outPipe.fileHandleForReading.readToEnd() {
                    collector.appendOut(rest)
                }
                if let rest = try? errPipe.fileHandleForReading.readToEnd() {
                    collector.appendErr(rest)
                }
                let (out, err) = collector.snapshot()
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: String(data: out, encoding: .utf8) ?? "")
                } else {
                    continuation.resume(throwing: CLIError(
                        command: ([executable.components(separatedBy: "/").last ?? executable] + arguments)
                            .joined(separator: " "),
                        exitCode: proc.terminationStatus,
                        stderr: String(data: err, encoding: .utf8) ?? ""
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Stream di output riga-per-blocco; la cancellazione del task
    /// consumatore termina il processo (usato per `logs --follow`).
    static func stream(executable: String, arguments: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let outPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = outPipe

            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                continuation.yield(text)
            }

            process.terminationHandler = { _ in
                outPipe.fileHandleForReading.readabilityHandler = nil
                continuation.finish()
            }

            continuation.onTermination = { _ in
                if process.isRunning { process.terminate() }
            }

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}

/// Accumulatore thread-safe per i readabilityHandler (girano su thread di GCD).
private final class DataCollector: @unchecked Sendable {
    private var out = Data()
    private var err = Data()
    private let lock = NSLock()

    func appendOut(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock(); out.append(data); lock.unlock()
    }

    func appendErr(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock(); err.append(data); lock.unlock()
    }

    func snapshot() -> (Data, Data) {
        lock.lock(); defer { lock.unlock() }
        return (out, err)
    }
}
