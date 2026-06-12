import SwiftUI

@main
struct ContainerDeckApp: App {
    @State private var appState = AppState()

    init() {
        // Hook diagnostico: `ContainerDeck --parse-compose <file>` stampa
        // il risultato del parsing compose senza avviare la UI.
        if let flag = CommandLine.arguments.firstIndex(of: "--parse-compose"),
           CommandLine.arguments.count > flag + 1 {
            Self.debugParseCompose(path: CommandLine.arguments[flag + 1])
        }

        // Necessario quando l'eseguibile gira fuori da un bundle .app
        // (es. `swift run` in sviluppo): senza, la finestra non viene attivata.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private static func debugParseCompose(path: String) -> Never {
        do {
            let stack = try ComposeParser.load(path: path)
            print("stack: \(stack.name)")
            print("volumi: \(stack.volumes.joined(separator: ", "))")
            for service in stack.services {
                print("\n[\(service.name)] → \(service.containerName(project: stack.name))")
                print("  origine: \(service.sourceLabel)")
                if !service.command.isEmpty { print("  command: \(service.command)") }
                if !service.ports.isEmpty { print("  porte: \(service.ports.joined(separator: ", "))") }
                if !service.env.isEmpty { print("  env: \(service.env.count) variabili") }
                for volume in service.volumes { print("  mount: \(volume)") }
                if !service.dependsOn.isEmpty { print("  dipende da: \(service.dependsOn.joined(separator: ", "))") }
            }
            if !stack.warnings.isEmpty {
                print("\navvertenze:")
                stack.warnings.forEach { print("  ⚠️ \($0)") }
            }
        } catch {
            print("errore: \(error.localizedDescription)")
        }
        exit(0)
    }

    var body: some Scene {
        WindowGroup("ContainerDeck") {
            MainWindow()
                .environment(appState)
                .frame(minWidth: 980, minHeight: 640)
                .task {
                    appState.startPolling()
                }
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(after: .newItem) {
                Button(L("Aggiorna")) {
                    Task { await appState.refreshAll() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
