import Foundation

/// Engine dimostrativo: permette di esplorare l'intera UI senza il runtime
/// apple/container installato. Attivabile da Impostazioni → Modalità demo.
final class MockEngine: ContainerEngine, @unchecked Sendable {
    private let lock = NSLock()

    private var containers: [DeckContainer] = [
        DeckContainer(id: "web-frontend", image: "docker.io/library/nginx:1.27", state: .running,
                      cpus: 2, memoryBytes: 512 << 20,
                      addresses: ["192.168.64.2"],
                      mounts: [MountInfo(source: "site-data", destination: "/usr/share/nginx/html")],
                      env: ["NGINX_PORT=80", "TZ=Europe/Rome"]),
        DeckContainer(id: "api", image: "docker.io/library/python:3.12-slim", state: .running,
                      cpus: 4, memoryBytes: 1 << 30,
                      addresses: ["192.168.64.3"],
                      env: ["ENV=production", "PORT=8000"]),
        DeckContainer(id: "postgres-dev", image: "docker.io/library/postgres:16", state: .stopped,
                      cpus: 2, memoryBytes: 2 << 30,
                      mounts: [MountInfo(source: "pgdata", destination: "/var/lib/postgresql/data")],
                      env: ["POSTGRES_DB=app"]),
        DeckContainer(id: "redis-cache", image: "docker.io/library/redis:7", state: .stopped,
                      cpus: 1, memoryBytes: 256 << 20)
    ]

    private var images: [DeckImage] = [
        DeckImage(reference: "docker.io/library/nginx:1.27", digest: "sha256:a1b2c3…", sizeBytes: 67 << 20),
        DeckImage(reference: "docker.io/library/python:3.12-slim", digest: "sha256:d4e5f6…", sizeBytes: 48 << 20),
        DeckImage(reference: "docker.io/library/postgres:16", digest: "sha256:9f8e7d…", sizeBytes: 158 << 20),
        DeckImage(reference: "docker.io/library/redis:7", digest: "sha256:7c6b5a…", sizeBytes: 41 << 20)
    ]

    private var volumes: [DeckVolume] = [
        DeckVolume(name: "pgdata", source: "~/Library/Application Support/container/volumes/pgdata", sizeBytes: 312 << 20),
        DeckVolume(name: "site-data", source: "~/Library/Application Support/container/volumes/site-data", sizeBytes: 24 << 20)
    ]

    private func mutate(_ change: (MockEngine) -> Void) {
        lock.lock(); change(self); lock.unlock()
    }

    private func sync<T>(_ read: (MockEngine) -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return read(self)
    }

    private func setState(_ id: String, _ state: ContainerState) {
        mutate { engine in
            if let i = engine.containers.firstIndex(where: { $0.id == id }) {
                engine.containers[i].state = state
            }
        }
    }

    func systemStatus() async -> EngineStatus { .running }
    func startSystem() async throws {}
    func stopSystem() async throws {}

    func listContainers() async throws -> [DeckContainer] {
        sync { $0.containers }
    }

    func listImages() async throws -> [DeckImage] {
        sync { $0.images }
    }

    func listVolumes() async throws -> [DeckVolume] {
        sync { $0.volumes }
    }

    func stats() async throws -> [ContainerStats] {
        sync { engine in
            engine.containers.filter { $0.state == .running }.enumerated().map { i, c in
                ContainerStats(id: c.id,
                               cpuPercent: [12.4, 3.7, 41.2][i % 3],
                               memoryBytes: [180 << 20, 412 << 20, 96 << 20][i % 3])
            }
        }
    }

    func diskUsageBytes() async throws -> Int64? { 1_240 << 20 }

    func start(_ id: String) async throws { setState(id, .running) }
    func stop(_ id: String) async throws { setState(id, .stopped) }
    func kill(_ id: String) async throws { setState(id, .stopped) }

    func delete(_ id: String, force: Bool) async throws {
        mutate { $0.containers.removeAll { $0.id == id } }
    }

    func run(spec: NewContainerSpec) async throws {
        let name = spec.name.nonEmpty ?? "container-\(Int.random(in: 1000...9999))"
        mutate { $0.containers.append(DeckContainer(id: name, image: spec.image, state: .running)) }
    }

    func pullImage(_ reference: String) async throws {
        try await Task.sleep(for: .seconds(1))
        mutate { $0.images.append(DeckImage(reference: reference, sizeBytes: 80 << 20)) }
    }

    func deleteImage(_ reference: String) async throws {
        mutate { $0.images.removeAll { $0.reference == reference } }
    }

    func buildImage(tag: String, contextDir: String, dockerfile: String?, target: String?) async throws {
        try await Task.sleep(for: .seconds(1))
        mutate { $0.images.append(DeckImage(reference: tag, sizeBytes: 120 << 20)) }
    }

    func createVolume(_ name: String) async throws {
        mutate { $0.volumes.append(DeckVolume(name: name, sizeBytes: 0)) }
    }

    func deleteVolume(_ name: String) async throws {
        mutate { $0.volumes.removeAll { $0.name == name } }
    }

    func exec(id: String, command: [String]) async throws {
        // Demo: nessun container reale, l'iniezione hosts è un no-op.
    }

    func logs(id: String, follow: Bool, lines: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var counter = 0
                continuation.yield("[demo] log del container \(id)\n")
                while follow && !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    counter += 1
                    continuation.yield("[demo] \(id) | evento n. \(counter): richiesta gestita in \(Int.random(in: 2...40)) ms\n")
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func shellCommand(id: String) -> String {
        "echo 'Modalità demo: nessun container reale per \(id)'"
    }
}
