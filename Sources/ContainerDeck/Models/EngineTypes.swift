import Foundation

/// Stato del runtime apple/container (servizi XPC + helper di sistema).
enum EngineStatus: Equatable {
    case unknown
    case notInstalled
    case stopped
    case running

    var label: String {
        switch self {
        case .unknown: return L("Verifica in corso…")
        case .notInstalled: return L("CLI non trovata")
        case .stopped: return L("Motore fermo")
        case .running: return L("Motore attivo")
        }
    }
}

/// Statistiche di un container, da `container stats --no-stream --format json`.
///
/// Schema CLI 1.0.0: `{"id": "...", "cpuUsageUsec": N, "memoryUsageBytes": N,
/// "networkRxBytes": N, "networkTxBytes": N, "numProcesses": N, ...}`.
/// La CPU arriva come tempo cumulativo: la percentuale viene calcolata
/// da AppState confrontando due campionamenti consecutivi.
struct ContainerStats: Identifiable {
    var id: String
    var cpuPercent: Double?
    var cpuUsageUsec: Int64?
    var memoryBytes: Int64?
    var networkRxBytes: Int64?
    var networkTxBytes: Int64?
    var processCount: Int?

    init(record: [String: Any]) {
        let j = JSONExtract(record)
        id = j.string("id") ?? j.string("container") ?? j.string("containerID") ?? j.string("name") ?? "—"
        cpuPercent = j.double("cpuPercent") ?? j.double("cpu.percent") ?? j.double("cpuUsagePercent")
        cpuUsageUsec = j.int64("cpuUsageUsec")
        memoryBytes = j.int64("memoryUsageBytes")
            ?? j.int64("memoryBytes")
            ?? j.int64("memoryUsageInBytes")
            ?? j.int64("memory.usageInBytes")
        networkRxBytes = j.int64("networkRxBytes") ?? j.int64("network.rxBytes")
        networkTxBytes = j.int64("networkTxBytes") ?? j.int64("network.txBytes")
        processCount = j.int("numProcesses")
    }

    init(id: String, cpuPercent: Double?, memoryBytes: Int64?) {
        self.id = id
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
    }
}

enum ContainerAction: String {
    case start, stop, restart, kill, delete
}

/// Formattazione condivisa per byte e percentuali.
enum Format {
    static func bytes(_ value: Int64?) -> String {
        guard let value else { return "—" }
        return ByteCountFormatter.string(fromByteCount: value, countStyle: .memory)
    }

    static func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f %%", value)
    }
}
