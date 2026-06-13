import Foundation

/// Suite di test senza dipendenze, eseguibile coi soli Command Line Tools
/// (XCTest/Swift Testing richiederebbero Xcode, che il progetto non esige).
/// Avvio: `ContainerDeck --run-tests` (vedi ContainerDeckApp), oppure
/// `make test`. Copre la logica pura: parsing JSON tollerante, mapping dei
/// modelli sullo schema CLI 1.0.0, generazione argomenti, parser compose.
enum SelfTests {

    final class Reporter {
        private(set) var passed = 0
        private(set) var failed = 0
        private(set) var failures: [String] = []
        private var suite = ""

        func suite(_ name: String) { suite = name }

        func check(_ condition: Bool, _ message: String,
                   file: StaticString = #fileID, line: UInt = #line) {
            if condition {
                passed += 1
            } else {
                failed += 1
                failures.append("✗ [\(suite)] \(message)  (\(file):\(line))")
            }
        }

        func eq<T: Equatable>(_ a: T, _ b: T, _ message: String,
                              file: StaticString = #fileID, line: UInt = #line) {
            check(a == b, "\(message) — atteso \(b), ottenuto \(a)", file: file, line: line)
        }
    }

    /// Esegue tutta la suite, stampa il riepilogo, ritorna true se tutto verde.
    static func run() -> Bool {
        let r = Reporter()
        jsonExtract(r)
        modelMapping(r)
        newContainerSpec(r)
        composeInterpolation(r)
        composeParser(r)

        print("")
        if r.failed == 0 {
            print("✓ Tutti i test passati: \(r.passed) asserzioni")
        } else {
            print("Fallimenti (\(r.failed)):")
            r.failures.forEach { print("  \($0)") }
            print("\n\(r.passed) passate, \(r.failed) fallite")
        }
        return r.failed == 0
    }

    // MARK: JSONExtract

    private static func jsonExtract(_ r: Reporter) {
        r.suite("JSONExtract")
        let record: [String: Any] = [
            "configuration": [
                "id": "web",
                "resources": ["cpus": 4, "memoryInBytes": 1_073_741_824],
                "ratio": 12.5
            ]
        ]
        let j = JSONExtract(record)
        r.eq(j.string("configuration.id"), "web", "dotted string")
        r.eq(j.int("configuration.resources.cpus"), 4, "dotted int")
        r.eq(j.int64("configuration.resources.memoryInBytes"), 1_073_741_824, "dotted int64")
        r.eq(j.double("configuration.ratio"), 12.5, "dotted double")
        r.check(j.string("configuration.nope") == nil, "missing path → nil")
        r.check(j.string("configuration.id.x.y") == nil, "over-deep path → nil")

        let nets = JSONExtract(["networks": [["address": "10.0.0.1"], ["address": "10.0.0.2"]]])
            .dictArray("networks")
        r.eq(nets.count, 2, "dictArray count")

        r.eq(JSONExtract.records(from: #"[{"id":"a"},{"id":"b"}]"#).count, 2, "records: array")
        r.eq(JSONExtract.records(from: #"{"id":"only"}"#).count, 1, "records: single object wrapped")
        r.check(JSONExtract.records(from: "not json").isEmpty, "records: invalid → empty")
    }

    // MARK: Mapping modelli (schema CLI 1.0.0)

    private static func modelMapping(_ r: Reporter) {
        r.suite("ModelMapping")
        let containerRecord: [String: Any] = [
            "id": "test",
            "configuration": [
                "id": "test",
                "image": ["reference": "docker.io/library/nginx:alpine"],
                "platform": ["os": "linux", "architecture": "arm64"],
                "resources": ["cpus": 4, "memoryInBytes": 1_073_741_824],
                "initProcess": ["environment": ["TZ=Europe/Rome", "PORT=80"]]
            ],
            "status": [
                "state": "running",
                "startedDate": "2026-06-11T19:06:03Z",
                "networks": [["ipv4Address": "192.168.64.2/24"]]
            ]
        ]
        let c = DeckContainer(record: containerRecord)
        r.eq(c.state, .running, "container state from status.state")
        r.eq(c.image, "docker.io/library/nginx:alpine", "container image")
        r.eq(c.cpus, 4, "container cpus")
        r.eq(c.memoryBytes, 1_073_741_824, "container memory")
        r.eq(c.addresses, ["192.168.64.2"], "container IP (CIDR stripped)")
        r.eq(c.env.count, 2, "container env count")
        r.check(c.startedDate != nil, "container startedDate parsed")

        r.eq(ContainerState(raw: "exited"), .stopped, "state: exited → stopped")
        r.eq(ContainerState(raw: nil), .unknown, "state: nil → unknown")

        let imageRecord: [String: Any] = [
            "configuration": [
                "name": "docker.io/library/nginx:alpine",
                "creationDate": "2026-05-22T18:28:57Z",
                "descriptor": ["digest": "sha256:8b1e"]
            ],
            "variants": [
                ["platform": ["architecture": "amd64"], "size": 99_000_000],
                ["platform": ["architecture": "arm64"], "size": 26_046_713]
            ]
        ]
        let img = DeckImage(record: imageRecord)
        r.eq(img.reference, "docker.io/library/nginx:alpine", "image reference from configuration.name")
        r.eq(img.tag, "alpine", "image tag")
        r.eq(img.sizeBytes, 26_046_713, "image size prefers arm64 variant")
        r.check(img.created != nil, "image created parsed")

        let netRecord: [String: Any] = [
            "id": "default",
            "configuration": ["name": "default", "mode": "nat",
                              "labels": ["com.apple.container.resource.role": "builtin"]],
            "status": ["ipv4Subnet": "192.168.64.0/24", "ipv4Gateway": "192.168.64.1"]
        ]
        let net = DeckNetwork(record: netRecord)
        r.eq(net.subnet, "192.168.64.0/24", "network subnet")
        r.check(net.isBuiltin, "network builtin detected")

        let stats = ContainerStats(record: [
            "id": "test", "cpuUsageUsec": 13_325, "memoryUsageBytes": 16_355_328, "numProcesses": 6
        ])
        r.eq(stats.cpuUsageUsec, 13_325, "stats cpuUsageUsec")
        r.eq(stats.memoryBytes, 16_355_328, "stats memory")
        r.eq(stats.processCount, 6, "stats processes")
    }

    // MARK: NewContainerSpec

    private static func newContainerSpec(_ r: Reporter) {
        r.suite("NewContainerSpec")
        var minimal = NewContainerSpec()
        minimal.image = "nginx:alpine"
        r.eq(minimal.arguments, ["run", "--detach", "nginx:alpine"], "minimal arguments")

        var spec = NewContainerSpec()
        spec.name = "web"; spec.image = "nginx:alpine"; spec.cpus = "2"; spec.memory = "512M"
        spec.ports = "8080:80\n443:443"; spec.env = "ENV=prod\nTZ=Europe/Rome"
        spec.volumes = "data:/var/lib/data"; spec.command = "nginx -g daemon off;"
        let a = spec.arguments
        r.check(contiguous(a, ["--name", "web"]), "arg --name")
        r.check(contiguous(a, ["--cpus", "2"]), "arg --cpus")
        r.check(contiguous(a, ["--memory", "512M"]), "arg --memory")
        r.check(contiguous(a, ["--publish", "8080:80"]), "arg --publish 1")
        r.check(contiguous(a, ["--publish", "443:443"]), "arg --publish 2")
        r.check(contiguous(a, ["--env", "ENV=prod"]), "arg --env")
        r.check(contiguous(a, ["--volume", "data:/var/lib/data"]), "arg --volume")
        if let i = a.firstIndex(of: "nginx:alpine") {
            r.check(a[(i + 1)...].starts(with: ["nginx", "-g", "daemon", "off;"]),
                    "command tokens follow image")
        } else { r.check(false, "image present in args") }

        var blanks = NewContainerSpec()
        blanks.image = "alpine"; blanks.env = "A=1\n\n  \nB=2"
        r.eq(blanks.arguments.filter { $0 == "--env" }.count, 2, "blank env lines dropped")

        r.eq("  a \n\n b \n".lines, ["a", "b"], "String.lines trims & drops empties")
    }

    // MARK: Compose interpolation

    private static func composeInterpolation(_ r: Reporter) {
        r.suite("ComposeInterpolation")
        r.eq(ComposeParser.interpolate("db=${NAME}", dotEnv: ["NAME": "timbrico"]),
             "db=timbrico", "${VAR} from .env")
        // DBUSER scelto perché non presente nell'ambiente di processo
        // (USER lo è: avrebbe la precedenza sul default, mascherando il test).
        r.eq(ComposeParser.interpolate("u=${DBUSER:-user}", dotEnv: [:]),
             "u=user", "${VAR:-default} fallback")
        r.eq(ComposeParser.interpolate("u=${DBUSER:-user}", dotEnv: ["DBUSER": "admin"]),
             "u=admin", "${VAR:-default} overridden")
        r.eq(ComposeParser.interpolate("postgresql://${U:-user}:${P:-pass}@db/${D:-app}", dotEnv: [:]),
             "postgresql://user:pass@db/app", "multiple interpolations")
    }

    // MARK: Compose parser (su file temporaneo)

    private static let composeYAML = """
    services:
      db:
        image: postgres:15-alpine
        restart: always
        volumes:
          - postgres_data:/var/lib/postgresql/data
        environment:
          - POSTGRES_DB=${POSTGRES_DB:-timbrico}
        ports:
          - "5432:5432"
      backend:
        build: ./backend
        volumes:
          - ./backend:/app
          - /var/run/docker.sock:/var/run/docker.sock:ro
        ports:
          - "8000:8000"
        depends_on:
          - db
      frontend:
        build:
          context: ./frontend
          target: production
        ports:
          - "5173:5173"
        depends_on:
          - backend
    volumes:
      postgres_data:
    """

    private static func composeParser(_ r: Reporter) {
        r.suite("ComposeParser")
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cdtest-\(UInt64.random(in: 0..<UInt64.max))")
        defer { try? FileManager.default.removeItem(at: dir) }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let file = dir.appendingPathComponent("docker-compose.yml")
            try composeYAML.write(to: file, atomically: true, encoding: .utf8)
            let stack = try ComposeParser.load(path: file.path)

            r.eq(stack.services.count, 3, "service count")
            r.eq(stack.volumes, ["postgres_data"], "named volumes")

            let names = stack.services.map(\.name)
            if let db = names.firstIndex(of: "db"),
               let be = names.firstIndex(of: "backend"),
               let fe = names.firstIndex(of: "frontend") {
                r.check(db < be && be < fe, "depends_on topological order")
            } else { r.check(false, "all services present") }

            let db = stack.services.first { $0.name == "db" }!
            r.eq(db.containerName(project: stack.name), "db", "bare container name")
            r.check(db.env.contains("POSTGRES_DB=timbrico"), "interpolated env reaches service")

            let frontend = stack.services.first { $0.name == "frontend" }!
            r.check(frontend.image == nil, "build service has no image")
            r.check(frontend.buildContext?.hasPrefix("/") == true, "build context absolute")
            r.check(frontend.buildContext?.hasSuffix("/frontend") == true, "build context path")
            r.eq(frontend.buildTarget, "production", "build target captured")

            let backend = stack.services.first { $0.name == "backend" }!
            r.check(stack.warnings.contains { $0.contains("docker.sock") }, "warns on docker.sock")
            r.check(stack.warnings.contains { $0.contains("restart") }, "warns on restart")
            r.check(!backend.volumes.contains { $0.contains("docker.sock") }, "socket mount skipped")
            r.check(backend.volumes.contains { $0.hasSuffix("/backend:/app") && $0.hasPrefix("/") },
                    "bind mount resolved to absolute path")
        } catch {
            r.check(false, "compose parse threw: \(error.localizedDescription)")
        }
    }

    // MARK: Helper

    private static func contiguous(_ haystack: [String], _ needle: [String]) -> Bool {
        guard needle.count <= haystack.count, !needle.isEmpty else { return false }
        for offset in 0...(haystack.count - needle.count)
        where Array(haystack[offset..<offset + needle.count]) == needle {
            return true
        }
        return false
    }
}
