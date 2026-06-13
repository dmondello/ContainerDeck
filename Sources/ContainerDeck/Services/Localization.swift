import Foundation
import Observation

/// Lingua dell'interfaccia, cambiabile a runtime dalle Impostazioni.
/// Essendo @Observable, qualunque vista che passa da L()/LF() durante
/// il body si aggiorna automaticamente al cambio lingua.
@Observable
final class Localizer {
    static let shared = Localizer()
    static let defaultsKey = "appLanguage"

    var language: String {
        didSet { UserDefaults.standard.set(language, forKey: Self.defaultsKey) }
    }

    private init() {
        language = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? "en"
    }

    func translate(_ key: String) -> String {
        guard language == "en" else { return key }
        return Localizer.english[key] ?? key
    }
}

/// Traduzione di una stringa UI. La chiave è il testo italiano:
/// se manca la traduzione si degrada all'italiano senza rompere nulla.
func L(_ key: String) -> String {
    Localizer.shared.translate(key)
}

/// Variante con parametri (placeholder %@/%d in stile String(format:)).
func LF(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), arguments: args)
}

extension Localizer {
    static let english: [String: String] = [
        // Stati
        "In esecuzione": "Running",
        "Fermo": "Stopped",
        "Creato": "Created",
        "In pausa": "Paused",
        "Sconosciuto": "Unknown",
        "Verifica in corso…": "Checking…",
        "CLI non trovata": "CLI not found",
        "Motore fermo": "Engine stopped",
        "Motore attivo": "Engine running",

        // Sidebar e finestra
        "Container": "Containers",
        "Immagini": "Images",
        "Volumi": "Volumes",
        "Impostazioni": "Settings",
        "GUI per apple/container": "GUI for apple/container",
        "Avvia": "Start",
        "Aggiorna": "Refresh",

        // Dashboard
        "Container attivi": "Running containers",
        "Container fermi": "Stopped containers",
        "CPU complessiva": "Total CPU",
        "somma dei container attivi": "sum of running containers",
        "Memoria usata": "Memory used",
        "Spazio su disco": "Disk usage",
        "immagini e container": "images and containers",
        "Immagini locali": "Local images",
        "Container recenti": "Recent containers",
        "Installa apple/container da github.com/apple/container, oppure attiva la Modalità demo nelle Impostazioni.":
            "Install apple/container from github.com/apple/container, or enable Demo mode in Settings.",
        "Avvia il motore per gestire i container.": "Start the engine to manage containers.",
        "Avvia motore": "Start engine",
        "Aggiorna (⌘R)": "Refresh (⌘R)",

        // Errori e kernel
        "Manca il kernel Linux di default (setup iniziale del runtime). Scaricando quello consigliato i container potranno essere avviati.":
            "The default Linux kernel is missing (initial runtime setup). Download the recommended one to start containers.",
        "Manca il kernel Linux di default (setup iniziale del runtime). Posso scaricare e configurare quello consigliato, poi riprovare.":
            "The default Linux kernel is missing (initial runtime setup). I can download and configure the recommended one, then retry.",
        "Installa kernel": "Install kernel",
        "Installazione…": "Installing…",
        "Ignora errore": "Dismiss error",

        // Menu IP
        "Apri nel browser": "Open in browser",
        "Apri nel browser (HTTPS)": "Open in browser (HTTPS)",
        "Apri con VNC": "Open with VNC",
        "Apri con FTP": "Open with FTP",
        "Copia indirizzo": "Copy address",
        "Tasto destro per aprire con browser, VNC o FTP": "Right-click to open with browser, VNC or FTP",

        // Menu container
        "Ferma": "Stop",
        "Riavvia": "Restart",
        "Apri shell nel Terminale": "Open shell in Terminal",
        "Apri %@…": "Open %@…",
        "Copia ID": "Copy ID",
        "Elimina": "Delete",

        // Lista container
        "Nessun container": "No containers",
        "Crea un container con il pulsante + oppure verifica che il motore sia attivo.":
            "Create a container with the + button, or make sure the engine is running.",
        "Filtra per nome o immagine": "Filter by name or image",
        "Nuovo container": "New container",
        "Crea un nuovo container": "Create a new container",
        "Nome": "Name",
        "Immagine": "Image",
        "Stato": "Status",
        "Memoria": "Memory",
        "Azioni": "Actions",
        "Eliminare il container “%@”?": "Delete container “%@”?",
        "L'operazione non è reversibile.": "This operation cannot be undone.",

        // Creazione container
        "Base": "Basics",
        "Nome (opzionale)": "Name (optional)",
        "Comando (opzionale)": "Command (optional)",
        "Risorse": "Resources",
        "CPU (opzionale)": "CPUs (optional)",
        "Memoria (opzionale)": "Memory (optional)",
        "Rete e storage (una voce per riga)": "Network and storage (one entry per line)",
        "Porte host:container": "Ports host:container",
        "Variabili CHIAVE=valore": "Variables KEY=value",
        "Volumi sorgente:destinazione": "Volumes source:destination",
        "Annulla": "Cancel",
        "Crea ed esegui": "Create and run",
        "es. web-frontend": "e.g. web-frontend",
        "es. docker.io/library/nginx:latest": "e.g. docker.io/library/nginx:latest",
        "es. /bin/sh -c \"…\"": "e.g. /bin/sh -c \"…\"",
        "es. 2": "e.g. 2",
        "es. 512M oppure 2G": "e.g. 512M or 2G",

        // Dettaglio container
        "Panoramica": "Overview",
        "Container non trovato": "Container not found",
        "Il container “%@” non esiste più.": "Container “%@” no longer exists.",
        "Apri una shell nel container usando Terminale": "Open a shell in the container using Terminal",
        "Configurazione": "Configuration",
        "Piattaforma": "Platform",
        "CPU assegnate": "Assigned CPUs",
        "Memoria assegnata": "Assigned memory",
        "Indirizzi IP": "IP addresses",
        "Avviato": "Started",
        "Utilizzo risorse": "Resource usage",
        "Processi": "Processes",
        "Rete ↓ / ↑": "Network ↓ / ↑",
        "Volumi montati": "Mounted volumes",
        "Variabili d'ambiente": "Environment variables",

        // Log viewer
        "Filtra log…": "Filter logs…",
        "Segui": "Follow",
        "Copia": "Copy",
        "Copia i log visibili negli appunti": "Copy visible logs to clipboard",
        "Pulisci": "Clear",
        "⚠️ Errore lettura log: %@": "⚠️ Error reading logs: %@",

        // Immagini
        "Nessuna immagine locale": "No local images",
        "Scarica un'immagine da un registry con il pulsante ⤓.": "Pull an image from a registry with the ⤓ button.",
        "Riferimento": "Reference",
        "Dimensione": "Size",
        "Creazione": "Created",
        "Elimina immagine": "Delete image",
        "Filtra immagini": "Filter images",
        "Scarica immagine": "Pull image",
        "Crea container…": "Create container…",
        "Copia riferimento": "Copy reference",
        "Eliminare l'immagine “%@”?": "Delete image “%@”?",
        "es. docker.io/library/alpine:latest": "e.g. docker.io/library/alpine:latest",
        "Vengono supportati i registry OCI compatibili (Docker Hub, GHCR, ECR…).":
            "OCI-compatible registries are supported (Docker Hub, GHCR, ECR…).",
        "Scarica": "Pull",
        "Download…": "Downloading…",

        // Volumi
        "Nessun volume": "No volumes",
        "Crea un volume nominato per persistere i dati dei container.":
            "Create a named volume to persist container data.",
        "Percorso": "Path",
        "Usato da": "Used by",
        "Elimina volume": "Delete volume",
        "Il volume è in uso da un container": "The volume is in use by a container",
        "Nuovo volume": "New volume",
        "Nome volume": "Volume name",
        "Crea": "Create",
        "Errore": "Error",
        "Eliminare il volume “%@”?": "Delete volume “%@”?",
        "I dati contenuti nel volume andranno persi.": "Data stored in the volume will be lost.",

        // Impostazioni
        "Runtime apple/container": "apple/container runtime",
        "Percorso CLI": "CLI path",
        "Rileva": "Detect",
        "Cerca il binario nei percorsi standard": "Look for the binary in standard locations",
        "Stato motore": "Engine status",
        "Ferma motore": "Stop engine",
        "Modalità demo (dati di esempio, nessun runtime richiesto)":
            "Demo mode (sample data, no runtime required)",
        "Interfaccia": "Interface",
        "Lingua": "Language",
        "Tema": "Theme",
        "Sistema": "System",
        "Chiaro": "Light",
        "Scuro": "Dark",
        "Aggiornamento dati": "Data refresh",
        "Diagnostica": "Diagnostics",
        "Esegui diagnostica": "Run diagnostics",
        "Esecuzione…": "Running…",
        "Informazioni": "About",
        "Versione app": "App version",
        "Progetto runtime": "Runtime project",

        // Stack (compose)
        "Stack": "Stacks",
        "Apri compose…": "Open compose…",
        "Nessuno stack caricato": "No stack loaded",
        "Apri un docker-compose.yml per orchestrare più container insieme.":
            "Open a docker-compose.yml to orchestrate multiple containers together.",
        "Avvia stack": "Start stack",
        "Ferma stack": "Stop stack",
        "Rimuovi stack": "Tear down stack",
        "Servizio": "Service",
        "Origine": "Source",
        "Nome container": "Container name",
        "Porte": "Ports",
        "Non creato": "Not created",
        "Avvio dello stack “%@”…": "Starting stack “%@”…",
        "Arresto dello stack…": "Stopping stack…",
        "Rimozione dei container dello stack…": "Removing stack containers…",
        "Eliminare i container dello stack “%@”?": "Delete the containers of stack “%@”?",
        "I volumi nominati non vengono eliminati.": "Named volumes are not deleted.",
        "Build di %@…": "Building %@…",
        "Volume %@ creato": "Volume %@ created",
        "Volume %@ già presente": "Volume %@ already exists",
        "Avvio interrotto: i servizi dipendenti non sono stati avviati.":
            "Startup aborted: dependent services were not started.",

        // Service discovery (/etc/hosts)
        "Raggiungibile come": "Reachable as",
        "Nome con cui gli altri servizi raggiungono questo container":
            "The name other services use to reach this container",
        "Discovery per nome": "Name discovery",
        "All'avvio i servizi vengono resi raggiungibili per nome via /etc/hosts":
            "On start, services are made reachable by name via /etc/hosts",
        "Configurazione service discovery (/etc/hosts)…":
            "Wiring service discovery (/etc/hosts)…",
        "Service discovery attivo: %@": "Service discovery active: %@",

        // Terminale integrato
        "Shell integrata": "Built-in shell",
        "Apri in Terminale.app": "Open in Terminal.app",
        "Apri una shell nel container": "Open a shell in the container",
        "Shell — %@": "Shell — %@",

        // Multi-log
        "Log": "Logs",
        "Log combinati": "Combined logs",
        "Log combinati (%d container)": "Combined logs (%d containers)",
        "Log combinati dei servizi in esecuzione": "Combined logs of running services",
        "Log combinati di tutti i container in esecuzione": "Combined logs of all running containers",
        "Chiudi": "Close",
        "Mostra": "Show",
        "Nascondi": "Hide",

        // Reti
        "Reti": "Networks",
        "Nessuna rete": "No networks",
        "Crea una rete per isolare gruppi di container (richiede macOS 26).":
            "Create a network to isolate groups of containers (requires macOS 26).",
        "predefinita": "default",
        "Modalità": "Mode",
        "Subnet": "Subnet",
        "Gateway": "Gateway",
        "La rete predefinita non è eliminabile": "The default network cannot be deleted",
        "Elimina rete": "Delete network",
        "Nuova rete": "New network",
        "Nome rete": "Network name",
        "Le reti richiedono macOS 26.": "Networks require macOS 26.",
        "Eliminare la rete “%@”?": "Delete network “%@”?"
    ]
}
