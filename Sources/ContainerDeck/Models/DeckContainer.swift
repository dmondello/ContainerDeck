import Foundation

/// Stato normalizzato di un container, derivato dal campo `status` della CLI.
enum ContainerState: String, CaseIterable {
    case running
    case stopped
    case created
    case paused
    case unknown

    init(raw: String?) {
        switch raw?.lowercased() {
        case "running": self = .running
        case "stopped", "exited": self = .stopped
        case "created": self = .created
        case "paused": self = .paused
        default: self = .unknown
        }
    }

    var label: String {
        switch self {
        case .running: return L("In esecuzione")
        case .stopped: return L("Fermo")
        case .created: return L("Creato")
        case .paused: return L("In pausa")
        case .unknown: return L("Sconosciuto")
        }
    }
}

struct MountInfo: Hashable {
    var source: String
    var destination: String
}

/// Modello di dominio per un container, mappato in modo tollerante
/// dal JSON di `container ls --all --format json`.
struct DeckContainer: Identifiable, Hashable {
    let id: String
    var image: String
    var state: ContainerState
    var os: String?
    var arch: String?
    var cpus: Int?
    var memoryBytes: Int64?
    var addresses: [String]
    var mounts: [MountInfo]
    var env: [String]
    var startedDate: Date?
    /// JSON originale del record, mostrato nel tab Inspector del dettaglio.
    var rawJSON: String

    /// Mapping difensivo: lo schema JSON della CLI può variare tra versioni,
    /// quindi ogni campo viene cercato su più percorsi e degrada a un default.
    /// Schema CLI 1.0.0: `status` è un oggetto con `state`, `startedDate`
    /// e `networks[].ipv4Address`.
    init(record: [String: Any]) {
        let j = JSONExtract(record)
        id = j.string("configuration.id") ?? j.string("id") ?? "—"
        image = j.string("configuration.image.reference")
            ?? j.string("image.reference")
            ?? j.string("image")
            ?? "—"
        state = ContainerState(raw: j.string("status.state") ?? j.string("status") ?? j.string("state"))
        if let started = j.string("status.startedDate") {
            startedDate = ISO8601DateFormatter().date(from: started)
        }
        os = j.string("configuration.platform.os") ?? j.string("platform.os")
        arch = j.string("configuration.platform.architecture") ?? j.string("platform.architecture")
        cpus = j.int("configuration.resources.cpus") ?? j.int("resources.cpus")
        memoryBytes = j.int64("configuration.resources.memoryInBytes") ?? j.int64("resources.memoryInBytes")

        var found: [String] = []
        for net in j.dictArray("status.networks") + j.dictArray("networks") {
            let n = JSONExtract(net)
            if let addr = n.string("ipv4Address") ?? n.string("address") ?? n.string("ipv4") ?? n.string("ip") {
                // L'indirizzo arriva in notazione CIDR (es. 192.168.64.2/24).
                found.append(String(addr.split(separator: "/").first ?? Substring(addr)))
            }
        }
        addresses = found

        var foundMounts: [MountInfo] = []
        for m in j.dictArray("configuration.mounts") + j.dictArray("mounts") {
            let mj = JSONExtract(m)
            let dest = mj.string("destination") ?? mj.string("target") ?? "?"
            let src = mj.string("source") ?? mj.string("type.virtiofs.source") ?? mj.string("name") ?? "?"
            foundMounts.append(MountInfo(source: src, destination: dest))
        }
        mounts = foundMounts

        env = (j.stringArray("configuration.initProcess.environment")
            ?? j.stringArray("configuration.env")
            ?? [])

        rawJSON = JSONExtract.pretty(record)
    }

    init(id: String, image: String, state: ContainerState,
         cpus: Int? = nil, memoryBytes: Int64? = nil,
         addresses: [String] = [], mounts: [MountInfo] = [], env: [String] = [],
         startedDate: Date? = nil) {
        self.id = id
        self.image = image
        self.state = state
        self.os = "linux"
        self.arch = "arm64"
        self.cpus = cpus
        self.memoryBytes = memoryBytes
        self.addresses = addresses
        self.mounts = mounts
        self.env = env
        self.startedDate = startedDate
        self.rawJSON = "{\n  \"id\": \"\(id)\" // dati demo\n}"
    }
}

/// Parametri di creazione di un nuovo container (mappati su `container run`).
struct NewContainerSpec {
    var name: String = ""
    var image: String = ""
    var command: String = ""
    /// Una riga per mapping, formato "hostPort:containerPort".
    var ports: String = ""
    /// Una riga per variabile, formato "CHIAVE=valore".
    var env: String = ""
    /// Una riga per mount, formato "sorgente:destinazione".
    var volumes: String = ""
    var cpus: String = ""
    /// Stringa passata a --memory (es. "512M", "2G").
    var memory: String = ""

    var arguments: [String] {
        var args = ["run", "--detach"]
        let name = name.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { args += ["--name", name] }
        let cpus = cpus.trimmingCharacters(in: .whitespaces)
        if !cpus.isEmpty { args += ["--cpus", cpus] }
        let memory = memory.trimmingCharacters(in: .whitespaces)
        if !memory.isEmpty { args += ["--memory", memory] }
        for line in ports.lines { args += ["--publish", line] }
        for line in env.lines { args += ["--env", line] }
        for line in volumes.lines { args += ["--volume", line] }
        args.append(image.trimmingCharacters(in: .whitespaces))
        let command = command.trimmingCharacters(in: .whitespaces)
        if !command.isEmpty {
            args += command.components(separatedBy: " ").filter { !$0.isEmpty }
        }
        return args
    }
}

extension String {
    /// Righe non vuote, già ripulite dagli spazi.
    var lines: [String] {
        components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
