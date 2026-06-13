import Foundation
import Yams

/// Un servizio di un file docker-compose.yml, già normalizzato:
/// percorsi risolti, env interpolate, pronto per diventare un container.
struct ComposeService: Identifiable, Hashable {
    var name: String
    /// Immagine da registry, oppure nil se il servizio va costruito.
    var image: String?
    /// Directory di build (assoluta) per i servizi con `build:`.
    var buildContext: String?
    var buildTarget: String?
    var dockerfile: String?
    var command: String = ""
    var ports: [String] = []
    var env: [String] = []
    var volumes: [String] = []
    var dependsOn: [String] = []

    var id: String { name }

    /// Il container ID è il nome di servizio PURO (non prefissato col
    /// progetto): è ciò che il DNS locale registra come `<nome>.<dominio>`,
    /// e ciò a cui puntano le reference nel compose (es. `@db`,
    /// `http://superset:8088`). Conseguenza: i nomi di servizio devono
    /// essere unici tra gli stack in esecuzione contemporaneamente.
    func containerName(project: String) -> String { name }
    func buildTag(project: String) -> String { "\(project)-\(name):latest" }

    /// Etichetta dell'origine mostrata in UI.
    var sourceLabel: String {
        if let image { return image }
        if let buildContext {
            let dir = URL(fileURLWithPath: buildContext).lastPathComponent
            return "build: ./\(dir)" + (buildTarget.map { " (\($0))" } ?? "")
        }
        return "—"
    }
}

/// Uno stack compose caricato: servizi in ordine di avvio (depends_on
/// risolto topologicamente), volumi nominati e avvertenze di parsing.
struct ComposeStack {
    var name: String
    var path: String
    /// Servizi già in ordine di avvio.
    var services: [ComposeService]
    var volumes: [String]
    var warnings: [String]
}

enum ComposeError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        if case .invalid(let message) = self { return message }
        return nil
    }
}

/// Parser per il sottoinsieme sensato di docker-compose.yml:
/// services (image/build/command/ports/environment/volumes/depends_on),
/// volumes top-level, interpolazione ${VAR} e ${VAR:-default} da .env
/// e ambiente di processo. restart/healthcheck vengono ignorati con avviso.
enum ComposeParser {

    static func load(path: String) throws -> ComposeStack {
        let url = URL(fileURLWithPath: path)
        let dir = url.deletingLastPathComponent()
        let rawText = try String(contentsOf: url, encoding: .utf8)
        let dotEnv = loadDotEnv(dir: dir)
        let text = interpolate(rawText, dotEnv: dotEnv)

        guard let parsed = try Yams.load(yaml: text) else {
            throw ComposeError.invalid("YAML vuoto")
        }
        let root = stringDict(parsed)
        let servicesRaw = stringDict(root["services"])
        guard !servicesRaw.isEmpty else {
            throw ComposeError.invalid("Nessuna sezione `services` nel file")
        }

        var warnings: [String] = []
        let namedVolumes = Array(stringDict(root["volumes"]).keys).sorted()
        let project = dir.lastPathComponent
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")

        var services: [ComposeService] = []
        for (name, raw) in servicesRaw {
            let s = stringDict(raw)
            var service = ComposeService(name: name)

            service.image = s["image"] as? String

            if let build = s["build"] {
                if let context = build as? String {
                    service.buildContext = resolvePath(context, dir: dir)
                } else {
                    let b = stringDict(build)
                    if let context = b["context"] as? String {
                        service.buildContext = resolvePath(context, dir: dir)
                    }
                    service.buildTarget = b["target"] as? String
                    service.dockerfile = (b["dockerfile"] as? String).map {
                        resolvePath($0, dir: dir)
                    }
                }
            }
            if service.image == nil && service.buildContext == nil {
                warnings.append("\(name): né `image` né `build`, servizio ignorato")
                continue
            }

            if let command = s["command"] as? String {
                service.command = command
            } else if let command = s["command"] as? [Any] {
                service.command = command.map { "\($0)" }.joined(separator: " ")
            }

            for port in s["ports"] as? [Any] ?? [] {
                let p = "\(port)"
                service.ports.append(p.contains(":") ? p : "\(p):\(p)")
            }

            if let envList = s["environment"] as? [Any] {
                service.env = envList.map { "\($0)" }
            } else {
                let envMap = stringDict(s["environment"])
                service.env = envMap.map { "\($0.key)=\($0.value)" }.sorted()
            }

            for entry in s["volumes"] as? [Any] ?? [] {
                if let resolved = resolveVolume("\(entry)", dir: dir, serviceName: name, warnings: &warnings) {
                    service.volumes.append(resolved)
                }
            }

            if let deps = s["depends_on"] as? [Any] {
                service.dependsOn = deps.map { "\($0)" }
            } else {
                service.dependsOn = Array(stringDict(s["depends_on"]).keys)
            }

            if let containerName = s["container_name"] as? String {
                // Il nome esplicito sostituisce la convenzione progetto-servizio.
                service.name = name
                warnings.append("\(name): container_name “\(containerName)” ignorato, uso \(project)-\(name)")
            }
            if s["restart"] != nil {
                warnings.append("\(name): `restart` non supportato dal runtime, ignorato")
            }
            if s["healthcheck"] != nil {
                warnings.append("\(name): `healthcheck` non supportato, ignorato")
            }

            services.append(service)
        }

        let ordered = topologicalSort(services, warnings: &warnings)
        return ComposeStack(name: project, path: path, services: ordered,
                            volumes: namedVolumes, warnings: warnings)
    }

    // MARK: Helpers

    /// Yams restituisce mapping con chiavi AnyHashable: normalizza a [String: Any].
    private static func stringDict(_ any: Any?) -> [String: Any] {
        guard let dict = any as? [AnyHashable: Any] else { return [:] }
        var out: [String: Any] = [:]
        for (key, value) in dict { out["\(key.base)"] = value }
        return out
    }

    private static func resolvePath(_ path: String, dir: URL) -> String {
        if path.hasPrefix("/") { return path }
        if path.hasPrefix("~") { return NSString(string: path).expandingTildeInPath }
        return dir.appendingPathComponent(path).standardized.path
    }

    private static func resolveVolume(_ entry: String, dir: URL, serviceName: String,
                                      warnings: inout [String]) -> String? {
        let parts = entry.split(separator: ":").map(String.init)
        guard parts.count >= 2 else {
            warnings.append("\(serviceName): mount “\(entry)” non valido, ignorato")
            return nil
        }
        var source = parts[0]
        let destination = parts[1]
        if source.hasPrefix("/var/run/") {
            warnings.append("\(serviceName): mount “\(entry)” (socket di sistema) non disponibile su apple/container, ignorato")
            return nil
        }
        if source.hasPrefix("./") || source.hasPrefix("../") || source.hasPrefix("/") || source.hasPrefix("~") {
            source = resolvePath(source, dir: dir)
        }
        if parts.count > 2 {
            warnings.append("\(serviceName): opzione “\(parts[2])” su “\(entry)” ignorata")
        }
        return "\(source):\(destination)"
    }

    private static func loadDotEnv(dir: URL) -> [String: String] {
        guard let text = try? String(contentsOf: dir.appendingPathComponent(".env"), encoding: .utf8) else {
            return [:]
        }
        var env: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
                  let eq = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[..<eq]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if value.count >= 2,
               (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            env[key] = value
        }
        return env
    }

    /// Sostituisce ${VAR} e ${VAR:-default} con .env → ambiente → default.
    static func interpolate(_ text: String, dotEnv: [String: String]) -> String {
        let pattern = #"\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-([^}]*))?\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let processEnv = ProcessInfo.processInfo.environment
        var result = ""
        var last = text.startIndex
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard let full = Range(match.range, in: text),
                  let nameRange = Range(match.range(at: 1), in: text) else { continue }
            result += text[last..<full.lowerBound]
            let name = String(text[nameRange])
            let fallback = Range(match.range(at: 2), in: text).map { String(text[$0]) }
            result += dotEnv[name] ?? processEnv[name] ?? fallback ?? ""
            last = full.upperBound
        }
        result += text[last...]
        return result
    }

    /// Ordina i servizi rispettando depends_on (Kahn); in caso di ciclo
    /// degrada all'ordine originale con avvertenza.
    private static func topologicalSort(_ services: [ComposeService],
                                        warnings: inout [String]) -> [ComposeService] {
        var remaining = services.sorted { $0.name < $1.name }
        var resolved: [ComposeService] = []
        var resolvedNames = Set<String>()
        let known = Set(services.map(\.name))

        while !remaining.isEmpty {
            let ready = remaining.filter { service in
                service.dependsOn.allSatisfy { !known.contains($0) || resolvedNames.contains($0) }
            }
            if ready.isEmpty {
                warnings.append("dipendenze circolari: ordine di avvio non garantito")
                return resolved + remaining
            }
            for service in ready {
                resolved.append(service)
                resolvedNames.insert(service.name)
            }
            remaining.removeAll { resolvedNames.contains($0.name) }
        }
        return resolved
    }
}
