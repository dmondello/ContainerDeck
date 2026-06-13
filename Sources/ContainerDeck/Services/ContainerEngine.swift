import Foundation

/// Astrazione del runtime container. L'app dipende solo da questo protocollo:
/// l'implementazione reale invoca la CLI di apple/container, quella mock
/// alimenta la UI con dati dimostrativi (utile senza runtime installato).
protocol ContainerEngine: Sendable {
    func systemStatus() async -> EngineStatus
    func startSystem() async throws
    func stopSystem() async throws

    func listContainers() async throws -> [DeckContainer]
    func listImages() async throws -> [DeckImage]
    func listVolumes() async throws -> [DeckVolume]
    func listNetworks() async throws -> [DeckNetwork]
    func stats() async throws -> [ContainerStats]
    func diskUsageBytes() async throws -> Int64?

    func start(_ id: String) async throws
    func stop(_ id: String) async throws
    func kill(_ id: String) async throws
    func delete(_ id: String, force: Bool) async throws
    func run(spec: NewContainerSpec) async throws

    func pullImage(_ reference: String) async throws
    func deleteImage(_ reference: String) async throws
    /// Costruisce un'immagine da un Dockerfile (richiede il builder BuildKit).
    func buildImage(tag: String, contextDir: String, dockerfile: String?, target: String?) async throws

    func createVolume(_ name: String) async throws
    func deleteVolume(_ name: String) async throws

    /// Reti richiedono macOS 26: create/delete possono fallire su 15.
    func createNetwork(_ name: String) async throws
    func deleteNetwork(_ name: String) async throws

    /// Esegue un comando dentro un container in esecuzione (`container exec`).
    /// Usato per il service discovery: iniezione di voci in /etc/hosts.
    func exec(id: String, command: [String]) async throws

    func logs(id: String, follow: Bool, lines: Int) -> AsyncThrowingStream<String, Error>
    /// Comando da eseguire in Terminale per aprire una shell nel container.
    func shellCommand(id: String) -> String
}

/// Implementazione reale: invoca il binario `container` di apple/container.
struct ContainerCLIService: ContainerEngine {
    let binaryPath: String

    static let defaultsKey = "containerBinaryPath"

    static let candidatePaths = [
        "/usr/local/bin/container",
        "/opt/homebrew/bin/container",
        "/usr/bin/container"
    ]

    /// Path configurato dall'utente, oppure primo candidato esistente.
    static func resolveBinaryPath() -> String {
        if let custom = UserDefaults.standard.string(forKey: defaultsKey), !custom.isEmpty {
            return custom
        }
        let fm = FileManager.default
        return candidatePaths.first { fm.isExecutableFile(atPath: $0) } ?? candidatePaths[0]
    }

    private func run(_ arguments: [String]) async throws -> String {
        try await CommandRunner.run(executable: binaryPath, arguments: arguments)
    }

    private func records(_ arguments: [String]) async throws -> [[String: Any]] {
        JSONExtract.records(from: try await run(arguments))
    }

    // MARK: Sistema

    func systemStatus() async -> EngineStatus {
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            return .notInstalled
        }
        do {
            _ = try await run(["system", "status"])
            return .running
        } catch {
            return .stopped
        }
    }

    func startSystem() async throws { _ = try await run(["system", "start"]) }
    func stopSystem() async throws { _ = try await run(["system", "stop"]) }

    // MARK: Liste

    func listContainers() async throws -> [DeckContainer] {
        try await records(["ls", "--all", "--format", "json"]).map(DeckContainer.init)
    }

    func listImages() async throws -> [DeckImage] {
        try await records(["image", "list", "--format", "json"]).map(DeckImage.init)
    }

    func listVolumes() async throws -> [DeckVolume] {
        try await records(["volume", "list", "--format", "json"]).map(DeckVolume.init)
    }

    func listNetworks() async throws -> [DeckNetwork] {
        try await records(["network", "list", "--format", "json"]).map(DeckNetwork.init)
    }

    func stats() async throws -> [ContainerStats] {
        try await records(["stats", "--no-stream", "--format", "json"]).map(ContainerStats.init)
    }

    func diskUsageBytes() async throws -> Int64? {
        let entries = try await records(["system", "df", "--format", "json"])
        // Schema CLI 1.0.0: oggetto con sezioni containers/images/volumes,
        // ognuna con il proprio sizeInBytes.
        if let summary = entries.first {
            let j = JSONExtract(summary)
            let total = ["containers", "images", "volumes"]
                .compactMap { j.int64("\($0).sizeInBytes") }
                .reduce(0, +)
            if total > 0 { return total }
        }
        // Fallback per eventuali schemi ad array di voci.
        let summed = entries
            .compactMap { JSONExtract($0).int64("size") ?? JSONExtract($0).int64("sizeInBytes") }
            .reduce(0, +)
        return summed > 0 ? summed : nil
    }

    // MARK: Ciclo di vita container

    func start(_ id: String) async throws { _ = try await run(["start", id]) }
    func stop(_ id: String) async throws { _ = try await run(["stop", id]) }
    func kill(_ id: String) async throws { _ = try await run(["kill", id]) }

    func delete(_ id: String, force: Bool) async throws {
        var args = ["delete", id]
        if force { args.insert("--force", at: 1) }
        _ = try await run(args)
    }

    func run(spec: NewContainerSpec) async throws {
        _ = try await run(spec.arguments)
    }

    // MARK: Immagini

    func pullImage(_ reference: String) async throws {
        _ = try await run(["image", "pull", reference])
    }

    func deleteImage(_ reference: String) async throws {
        _ = try await run(["image", "delete", reference])
    }

    func buildImage(tag: String, contextDir: String, dockerfile: String?, target: String?) async throws {
        var args = ["build", "--tag", tag]
        if let dockerfile { args += ["--file", dockerfile] }
        if let target { args += ["--target", target] }
        args.append(contextDir)
        do {
            _ = try await run(args)
        } catch {
            // Primo uso: il builder BuildKit potrebbe non essere avviato.
            _ = try? await run(["builder", "start"])
            _ = try await run(args)
        }
    }

    // MARK: Volumi

    func createVolume(_ name: String) async throws {
        _ = try await run(["volume", "create", name])
    }

    func deleteVolume(_ name: String) async throws {
        _ = try await run(["volume", "delete", name])
    }

    func createNetwork(_ name: String) async throws {
        _ = try await run(["network", "create", name])
    }

    func deleteNetwork(_ name: String) async throws {
        _ = try await run(["network", "delete", name])
    }

    func exec(id: String, command: [String]) async throws {
        _ = try await run(["exec", id] + command)
    }

    // MARK: Log e shell

    func logs(id: String, follow: Bool, lines: Int) -> AsyncThrowingStream<String, Error> {
        var args = ["logs"]
        if follow { args.append("--follow") }
        args += ["-n", String(lines), id]
        return CommandRunner.stream(executable: binaryPath, arguments: args)
    }

    func shellCommand(id: String) -> String {
        "\(binaryPath) exec --tty --interactive \(id) /bin/sh"
    }
}
