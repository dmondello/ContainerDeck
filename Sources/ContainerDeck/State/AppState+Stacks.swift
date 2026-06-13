import Foundation

/// Orchestrazione degli Stack (compose) per AppState. Le proprietà osservabili
/// `stack`/`stackLog`/`isStackBusy` restano in AppState; qui vivono solo il
/// caricamento, l'avvio/arresto e il service discovery.
@MainActor
extension AppState {

    private func slog(_ message: String) {
        stackLog.append(message)
    }

    func loadStack(path: String) {
        do {
            stack = try ComposeParser.load(path: path)
            stackLog = []
            UserDefaults.standard.set(path, forKey: Self.lastStackPathKey)
            for warning in stack?.warnings ?? [] {
                slog("⚠️ \(warning)")
            }
        } catch {
            stack = nil
            stackLog = ["✗ \(error.localizedDescription)"]
        }
    }

    /// Riapre in automatico l'ultimo stack usato (sezione Stack).
    func restoreLastStack() {
        guard stack == nil,
              let path = UserDefaults.standard.string(forKey: Self.lastStackPathKey),
              FileManager.default.fileExists(atPath: path) else { return }
        loadStack(path: path)
    }

    /// Stato del container associato a un servizio (nil = mai creato).
    func stackServiceState(_ service: ComposeService) -> ContainerState? {
        guard let stack else { return nil }
        return containers.first { $0.id == service.containerName(project: stack.name) }?.state
    }

    /// Avvia lo stack: volumi → build → run/start in ordine di depends_on.
    /// Niente attese su healthcheck (non supportati): tra un servizio e il
    /// successivo c'è solo una breve pausa.
    func stackUp() async {
        guard let stack, !isStackBusy else { return }
        isStackBusy = true
        defer { isStackBusy = false }
        slog(LF("Avvio dello stack “%@”…", stack.name))

        let engine = engine

        for volume in stack.volumes {
            if volumes.contains(where: { $0.name == volume }) {
                slog(LF("Volume %@ già presente", volume))
            } else {
                do {
                    try await engine.createVolume(volume)
                    slog(LF("Volume %@ creato", volume))
                } catch {
                    slog("⚠️ \(volume): \(error.localizedDescription)")
                }
            }
        }

        for service in stack.services {
            let containerName = service.containerName(project: stack.name)
            do {
                var imageRef = service.image
                if let context = service.buildContext {
                    let tag = service.buildTag(project: stack.name)
                    slog(LF("Build di %@…", service.name))
                    try await engine.buildImage(tag: tag, contextDir: context,
                                                dockerfile: service.dockerfile,
                                                target: service.buildTarget)
                    imageRef = tag
                }
                if let existing = containers.first(where: { $0.id == containerName }) {
                    if existing.state != .running {
                        try await engine.start(containerName)
                    }
                } else {
                    var spec = NewContainerSpec()
                    spec.name = containerName
                    spec.image = imageRef ?? ""
                    spec.command = service.command
                    spec.ports = service.ports.joined(separator: "\n")
                    spec.env = service.env.joined(separator: "\n")
                    spec.volumes = service.volumes.joined(separator: "\n")
                    try await engine.run(spec: spec)
                }
                slog("✓ \(service.name)")
                try? await Task.sleep(for: .seconds(1))
            } catch {
                slog("✗ \(service.name): \(error.localizedDescription)")
                slog(L("Avvio interrotto: i servizi dipendenti non sono stati avviati."))
                break
            }
        }

        await refreshAll()
        await wireServiceDiscovery(stack, engine: engine)
        await refreshAll()
    }

    /// Service discovery: apple/container 1.0.0 non risolve i container per
    /// nome tra loro, quindi dopo l'avvio iniettiamo in /etc/hosts di ogni
    /// servizio le coppie "<ip> <nome-servizio>" di tutti gli altri. Così le
    /// reference del compose (es. @db, http://superset:8088) funzionano.
    /// Interno (non private) perché lo richiama anche `perform` al restart.
    func wireServiceDiscovery(_ stack: ComposeStack, engine: ContainerEngine) async {
        var ipByService: [String: String] = [:]
        for service in stack.services {
            let name = service.containerName(project: stack.name)
            if let ip = containers.first(where: { $0.id == name })?.addresses.first {
                ipByService[service.name] = ip
            }
        }
        guard ipByService.count > 1 else { return }
        slog(L("Configurazione service discovery (/etc/hosts)…"))

        for service in stack.services {
            let containerName = service.containerName(project: stack.name)
            guard containers.first(where: { $0.id == containerName })?.state == .running else { continue }
            // Voci verso tutti gli altri servizi (non verso se stesso).
            let entries = ipByService
                .filter { $0.key != service.name }
                .map { "\($0.value) \($0.key)" }
            guard !entries.isEmpty else { continue }
            let line = entries.joined(separator: "\n")
            do {
                try await engine.exec(id: containerName,
                                      command: ["sh", "-c", "printf '%s\\n' \"\(line)\" >> /etc/hosts"])
            } catch {
                slog("⚠️ \(service.name): /etc/hosts — \(error.localizedDescription)")
            }
        }
        slog(LF("Service discovery attivo: %@", ipByService.keys.sorted().joined(separator: ", ")))
    }

    /// Ferma i container dello stack in ordine inverso di avvio.
    func stackStop() async {
        guard let stack, !isStackBusy else { return }
        isStackBusy = true
        defer { isStackBusy = false }
        slog(L("Arresto dello stack…"))
        let engine = engine
        for service in stack.services.reversed() {
            let containerName = service.containerName(project: stack.name)
            guard containers.first(where: { $0.id == containerName })?.state == .running else { continue }
            do {
                try await engine.stop(containerName)
                slog("✓ \(service.name)")
            } catch {
                slog("✗ \(service.name): \(error.localizedDescription)")
            }
        }
        await refreshAll()
    }

    /// Ferma ed elimina i container dello stack. I volumi nominati restano.
    func stackDown() async {
        guard let stack, !isStackBusy else { return }
        isStackBusy = true
        defer { isStackBusy = false }
        slog(L("Rimozione dei container dello stack…"))
        let engine = engine
        for service in stack.services.reversed() {
            let containerName = service.containerName(project: stack.name)
            guard containers.contains(where: { $0.id == containerName }) else { continue }
            do {
                try await engine.delete(containerName, force: true)
                slog("✓ \(service.name)")
            } catch {
                slog("✗ \(service.name): \(error.localizedDescription)")
            }
        }
        slog(L("I volumi nominati non vengono eliminati."))
        await refreshAll()
    }
}
