import Foundation

/// Volume nominato, da `container volume list --format json`.
struct DeckVolume: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var source: String?
    var sizeBytes: Int64?

    init(record: [String: Any]) {
        let j = JSONExtract(record)
        name = j.string("name") ?? j.string("id") ?? "—"
        source = j.string("source") ?? j.string("path") ?? j.string("mountpoint")
        sizeBytes = j.int64("sizeInBytes") ?? j.int64("size")
    }

    init(name: String, source: String? = nil, sizeBytes: Int64? = nil) {
        self.name = name
        self.source = source
        self.sizeBytes = sizeBytes
    }
}
