import Foundation

/// Apre Terminale.app ed esegue un comando (es. shell interattiva in un
/// container). Richiede l'autorizzazione Automazione al primo uso
/// (NSAppleEventsUsageDescription dichiarata nell'Info.plist).
enum TerminalLauncher {
    static func run(command: String) {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Terminal\"\nactivate\ndo script \"\(escaped)\"\nend tell"
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            try? process.run()
        }
    }
}
