import SwiftUI

@main
struct ContainerDeckApp: App {
    @State private var appState = AppState()

    init() {
        // Necessario quando l'eseguibile gira fuori da un bundle .app
        // (es. `swift run` in sviluppo): senza, la finestra non viene attivata.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
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
