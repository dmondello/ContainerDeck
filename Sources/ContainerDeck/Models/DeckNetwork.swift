import Foundation

/// Rete container, da `container network list --format json`.
/// Schema CLI 1.0.0: `{"id": "...", "configuration": {"name", "mode",
/// "plugin"}, "status": {"ipv4Subnet", "ipv4Gateway"}}`.
struct DeckNetwork: Identifiable, Hashable {
    var id: String
    var mode: String?
    var subnet: String?
    var gateway: String?
    /// Reti built-in (es. "default") non sono eliminabili.
    var isBuiltin: Bool

    init(record: [String: Any]) {
        let j = JSONExtract(record)
        id = j.string("configuration.name") ?? j.string("id") ?? "—"
        mode = j.string("configuration.mode")
        subnet = j.string("status.ipv4Subnet") ?? j.string("configuration.subnet")
        gateway = j.string("status.ipv4Gateway")
        isBuiltin = j.string("configuration.labels.com.apple.container.resource.role") == "builtin"
            || id == "default"
    }

    init(id: String, mode: String? = nil, subnet: String? = nil, gateway: String? = nil, isBuiltin: Bool = false) {
        self.id = id
        self.mode = mode
        self.subnet = subnet
        self.gateway = gateway
        self.isBuiltin = isBuiltin
    }
}
