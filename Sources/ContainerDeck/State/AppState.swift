import Foundation
import Observation

/// Stato centrale dell'app: cache osservabile delle risorse del runtime,
/// polling periodico e dispatch delle azioni verso l'engine.
@MainActor
@Observable
final class AppState {
    var engineStatus: EngineStatus = .unknown
    var containers: [DeckContainer] = []
    var images: [DeckImage] = []
    var volumes: [DeckVolume] = []
    var stats: [String: ContainerStats] = [:]
    var diskUsageBytes: Int64?
    var lastError: String?
    var isRefreshing = false
    var isInstallingKernel = false
    /// ID dei container con un'azione in corso (per disabilitare i pulsanti).
    var busyContainers: Set<String> = []

    private var pollTask: Task<Void, Never>?
    /// Ultimo campionamento CPU per container (tempo cumulativo in µs):
    /// serve a derivare la percentuale tra due rilevazioni consecutive.
    private var cpuSamples: [String: (usec: Int64, date: Date)] = [:]

    static let mockDefaultsKey = "useMockEngine"
    static let pollIntervalKey = "pollIntervalSeconds"

    /// L'engine viene risolto a ogni accesso così da reagire subito
    /// alle modifiche di path o modalità demo nelle Impostazioni.
    var engine: ContainerEngine {
        if UserDefaults.standard.bool(forKey: Self.mockDefaultsKey) {
            return Self.sharedMock
        }
        return ContainerCLIService(binaryPath: ContainerCLIService.resolveBinaryPath())
    }

    private static let sharedMock = MockEngine()

    var runningCount: Int { containers.filter { $0.state == .running }.count }
    var stoppedCount: Int { containers.count - runningCount }

    var totalCPUPercent: Double? {
        let values = stats.values.compactMap(\.cpuPercent)
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    var totalMemoryBytes: Int64? {
        let values = stats.values.compactMap(\.memoryBytes)
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    // MARK: Refresh

    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let engine = engine
        engineStatus = await engine.systemStatus()
        guard engineStatus == .running else {
            containers = []
            stats = [:]
            return
        }

        do {
            async let containersTask = engine.listContainers()
            async let imagesTask = engine.listImages()
            async let volumesTask = engine.listVolumes()
            containers = try await containersTask
            images = try await imagesTask
            volumes = try await volumesTask
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }

        // Statistiche e disco sono best-effort: un fallimento qui
        // non deve oscurare le liste già caricate.
        if containers.contains(where: { $0.state == .running }) {
            if let collected = try? await engine.stats() {
                stats = Dictionary(uniqueKeysWithValues: collected.map { ($0.id, withCPUPercent($0)) })
            }
        } else {
            stats = [:]
            cpuSamples = [:]
        }
        diskUsageBytes = (try? await engine.diskUsageBytes()) ?? nil
    }

    /// Deriva la percentuale CPU dal delta di tempo cumulativo (µs) tra
    /// questo campionamento e il precedente. 100% = un core saturo.
    private func withCPUPercent(_ stat: ContainerStats) -> ContainerStats {
        var stat = stat
        let now = Date()
        if let usec = stat.cpuUsageUsec {
            if stat.cpuPercent == nil,
               let previous = cpuSamples[stat.id],
               usec >= previous.usec {
                let elapsed = now.timeIntervalSince(previous.date)
                if elapsed > 0.5 {
                    stat.cpuPercent = Double(usec - previous.usec) / (elapsed * 1_000_000) * 100
                }
            }
            cpuSamples[stat.id] = (usec, now)
        }
        return stat
    }

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refreshAll()
                let stored = UserDefaults.standard.double(forKey: Self.pollIntervalKey)
                let interval = stored >= 2 ? stored : 5
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: Azioni

    func perform(_ action: ContainerAction, on id: String) async {
        busyContainers.insert(id)
        defer { busyContainers.remove(id) }
        do {
            let engine = engine
            switch action {
            case .start: try await engine.start(id)
            case .stop: try await engine.stop(id)
            case .kill: try await engine.kill(id)
            case .restart:
                try await engine.stop(id)
                try await engine.start(id)
            case .delete: try await engine.delete(id, force: true)
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        await refreshAll()
    }

    func createContainer(_ spec: NewContainerSpec) async throws {
        try await engine.run(spec: spec)
        await refreshAll()
    }

    func pullImage(_ reference: String) async throws {
        try await engine.pullImage(reference)
        await refreshAll()
    }

    func deleteImage(_ reference: String) async {
        do {
            try await engine.deleteImage(reference)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        await refreshAll()
    }

    func createVolume(_ name: String) async throws {
        try await engine.createVolume(name)
        await refreshAll()
    }

    func deleteVolume(_ name: String) async {
        do {
            try await engine.deleteVolume(name)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        await refreshAll()
    }

    /// True se l'ultimo errore è il kernel di default mancante
    /// (setup iniziale del runtime).
    var lastErrorIsKernelMissing: Bool {
        lastError?.contains("kernel not configured") == true
            || lastError?.contains("kernel set") == true
    }

    /// Scarica e configura il kernel raccomandato dal progetto apple/container.
    func installRecommendedKernel() async {
        isInstallingKernel = true
        defer { isInstallingKernel = false }
        do {
            _ = try await CommandRunner.run(
                executable: ContainerCLIService.resolveBinaryPath(),
                arguments: ["system", "kernel", "set", "--recommended"]
            )
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        await refreshAll()
    }

    func startEngine() async {
        do {
            try await engine.startSystem()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        await refreshAll()
    }

    func stopEngine() async {
        do {
            try await engine.stopSystem()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        await refreshAll()
    }

    /// I container che montano un volume: incrocio nomi/percorsi dei mount.
    func containersUsing(volume: DeckVolume) -> [DeckContainer] {
        containers.filter { container in
            container.mounts.contains {
                $0.source == volume.name || $0.source == volume.source
            }
        }
    }
}
