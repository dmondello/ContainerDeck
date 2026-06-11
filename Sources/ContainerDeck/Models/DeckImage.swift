import Foundation

/// Immagine OCI locale, da `container image list --format json`.
///
/// Schema CLI 1.0.0: `{"id": "<hex>", "configuration": {"name": "...",
/// "creationDate": "...", "descriptor": {"digest": "...", ...}},
/// "variants": [{"platform": {"architecture": "arm64"}, "size": N}, ...]}`.
struct DeckImage: Identifiable, Hashable {
    var id: String { reference }
    var reference: String
    var digest: String?
    var sizeBytes: Int64?
    var created: Date?

    var name: String {
        reference.split(separator: ":").dropLast().joined(separator: ":").nonEmpty ?? reference
    }

    var tag: String {
        if let last = reference.split(separator: ":").last, !last.contains("/") {
            return String(last)
        }
        return "latest"
    }

    init(record: [String: Any]) {
        let j = JSONExtract(record)
        reference = j.string("configuration.name") ?? j.string("reference") ?? j.string("name") ?? "—"
        digest = j.string("configuration.descriptor.digest")
            ?? j.string("descriptor.digest")
            ?? j.string("digest")
            ?? j.string("id")

        // La dimensione è per variante di piattaforma: si preferisce arm64
        // (l'unica eseguibile su Apple Silicon), altrimenti la più grande.
        let variants = j.dictArray("variants").map(JSONExtract.init)
        let arm64 = variants.first { $0.string("platform.architecture") == "arm64" }
        sizeBytes = arm64?.int64("size")
            ?? variants.compactMap { $0.int64("size") }.max()
            ?? j.int64("size")
            ?? j.int64("sizeInBytes")

        if let dateString = j.string("configuration.creationDate") ?? j.string("creationDate") {
            created = ISO8601DateFormatter().date(from: dateString)
        }
    }

    init(reference: String, digest: String? = nil, sizeBytes: Int64? = nil, created: Date? = nil) {
        self.reference = reference
        self.digest = digest
        self.sizeBytes = sizeBytes
        self.created = created
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
