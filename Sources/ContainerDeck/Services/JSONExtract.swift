import Foundation

/// Accesso tollerante a JSON arbitrario tramite percorsi puntati ("a.b.c").
///
/// Lo schema JSON di apple/container non è un contratto stabile tra release:
/// invece di Codable rigido, i modelli estraggono i campi provando più percorsi
/// e degradano a nil senza far fallire l'intero parsing.
struct JSONExtract {
    private let dict: [String: Any]

    init(_ dict: [String: Any]) { self.dict = dict }

    private func value(_ path: String) -> Any? {
        var current: Any? = dict
        for key in path.split(separator: ".") {
            guard let d = current as? [String: Any] else { return nil }
            current = d[String(key)]
        }
        return current
    }

    func string(_ path: String) -> String? {
        value(path) as? String
    }

    func int(_ path: String) -> Int? {
        if let n = value(path) as? NSNumber { return n.intValue }
        return nil
    }

    func int64(_ path: String) -> Int64? {
        if let n = value(path) as? NSNumber { return n.int64Value }
        return nil
    }

    func double(_ path: String) -> Double? {
        if let n = value(path) as? NSNumber { return n.doubleValue }
        return nil
    }

    func dictArray(_ path: String) -> [[String: Any]] {
        value(path) as? [[String: Any]] ?? []
    }

    func stringArray(_ path: String) -> [String]? {
        value(path) as? [String]
    }

    /// Decodifica l'output testuale della CLI come array di oggetti JSON.
    /// Accetta sia un array top-level sia un singolo oggetto.
    static func records(from text: String) -> [[String: Any]] {
        guard let data = text.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) else { return [] }
        if let array = parsed as? [[String: Any]] { return array }
        if let single = parsed as? [String: Any] { return [single] }
        return []
    }

    static func pretty(_ record: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: record,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
