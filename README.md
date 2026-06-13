# ContainerDeck

A native macOS GUI for [apple/container](https://github.com/apple/container)
on Apple Silicon: a lightweight Docker Desktop alternative, built with
Swift + SwiftUI — no Electron, no external runtimes.

![status](https://img.shields.io/badge/version-0.4.0-blue)
![platform](https://img.shields.io/badge/macOS-15%2B%20(arm64)-black)

## ContainerDeck vs Docker Desktop

![Docker Desktop vs ContainerDeck architecture](docs/architecture.png)

The difference is first of all architectural. Docker Desktop runs every
container inside **a single always-on Linux VM** (with GBs of RAM reserved
even when idle). apple/container instead spins up **a dedicated micro-VM per
container** on Apple's Virtualization framework: no idle monolithic VM,
stronger isolation (one kernel per container), a dedicated IP per container
with no mandatory port-forwarding, and sub-second boot optimized for
Apple Silicon.

| | Docker Desktop | ContainerDeck + apple/container |
|---|---|---|
| Architecture | single shared Linux VM | one micro-VM per container |
| Idle footprint | GBs of reserved RAM | ~zero |
| Isolation | shared kernel across containers | one kernel per container |
| Networking | port-forwarding from the VM | dedicated IP per container |
| App size | ~1.5 GB (Electron) | ~2.5 MB DMG (native SwiftUI) |
| Licensing | paid above company thresholds | open source + free app |
| Account/telemetry | required/present | none |
| Images | OCI (Docker Hub, GHCR…) | OCI (the same images) |

Where Docker Desktop is still ahead: **Docker Compose** (apple/container has
no equivalent yet), built-in Kubernetes, extensions, and ten years of
maturity. apple/container is at 1.0 and requires macOS 15+ on Apple Silicon
(macOS 26 for the advanced networking features). The two tools coexist on
the same machine without conflicts: lightweight local development →
ContainerDeck; complex multi-container orchestration → Docker Desktop.

## Features

Dashboard · containers (create / start / stop / restart / delete, detail with
live stats, env, mounts, raw JSON) · **Stacks** (docker-compose import with
service discovery) · images (pull / delete / create container) · volumes ·
**networks** · **combined multi-container log viewer** (color-coded, filter,
per-container toggle) · per-container live logs and shell · English/Italian
with live switching · light/dark theme · Demo mode without a runtime.

## Stacks: docker-compose support

apple/container has no native compose equivalent — ContainerDeck fills the
gap. The **Stacks** section imports a `docker-compose.yml` and orchestrates
it on the runtime:

- **Supported subset**: `services` (image / build context+target+dockerfile /
  command / ports / environment / volumes / depends_on / container_name),
  top-level named `volumes`, `${VAR}` and `${VAR:-default}` interpolation
  from a sibling `.env` file and the process environment.
- **Start order** follows `depends_on` (topological sort); builds run through
  `container build` (BuildKit), named volumes are created on the fly.
- **Ignored with a warning**: `restart` and `healthcheck` (not supported by
  the runtime), system socket mounts like `/var/run/docker.sock` (does not
  exist on apple/container), mount options such as `:ro`.
- **Service discovery is built in**: apple/container 1.0.0 does not resolve
  containers by name (no inter-container DNS, on the default network or a
  custom one — `container system dns create` only covers container→host).
  ContainerDeck closes the gap itself: once every service is running it
  collects their IPs and injects `<ip> <service>` lines into each
  container's `/etc/hosts`. Services are then reachable by their plain name
  (`db`, `http://superset:8088`) exactly as the compose file expects — no
  admin password, works on macOS 15. Because container IDs are global,
  **service names must be unique across stacks running at the same time**.
- Up / Stop / Tear down from the toolbar; tear down keeps named volumes.

## Requirements

- macOS 15 or later (macOS 26 recommended for apple/container networking features)
- Apple Silicon Mac
- [apple/container](https://github.com/apple/container/releases) installed
  (the official `.pkg` from the releases page) — **optional**: without the
  runtime, the app works in *Demo mode*, toggled from Settings
- To build: Swift 6.x (Command Line Tools are enough, Xcode is not required)

## Build and run

```sh
# Run in development
swift run

# Release build + ad-hoc signed .app bundle in dist/
make app

# Direct install
cp -r dist/ContainerDeck.app /Applications/

# Or: disk image for distribution (drag-and-drop to Applications)
make dmg     # → dist/ContainerDeck-<version>.dmg
```

## Installing the DMG

The DMG is **not notarized by Apple**, so on first launch macOS Gatekeeper
will block the app as coming from an unidentified developer. Allowing it
takes a few seconds:

1. Open the DMG and drag **ContainerDeck** to **Applications**.
2. Launch it once — macOS will refuse to open it. Close the dialog.
3. Go to **System Settings → Privacy & Security**, scroll down and click
   **"Open Anyway"** next to the ContainerDeck message, then confirm.
   (On recent macOS versions the old right-click → Open trick is no longer
   enough.)

This is only needed the first time; afterwards the app opens normally.
Alternatively, you can build it from source yourself (see above) — locally
built apps don't need this step.

## Architecture

```
Sources/ContainerDeck/
├── ContainerDeckApp.swift      SwiftUI entry point
├── Models/                     Domain models (tolerant JSON mapping)
│   ├── DeckContainer.swift     Container + NewContainerSpec (→ container run)
│   ├── DeckImage.swift         Local OCI images
│   ├── DeckVolume.swift        Named volumes
│   ├── DeckNetwork.swift       Container networks
│   ├── ComposeStack.swift      docker-compose parser (Stacks feature)
│   └── EngineTypes.swift       EngineStatus, ContainerStats, formatters
├── Services/
│   ├── ContainerEngine.swift   Protocol + real CLI implementation
│   ├── MockEngine.swift        Demo engine (explore the UI without a runtime)
│   ├── CommandRunner.swift     Async Process (one-shot run + streaming)
│   ├── JSONExtract.swift       Tolerant access to the CLI's JSON
│   ├── Localization.swift      In-app language switching (EN default / IT)
│   └── TerminalLauncher.swift  Opens interactive shells in Terminal.app
├── State/
│   └── AppState.swift          Observable state, polling, actions
└── Views/
    ├── MainWindow.swift        NavigationSplitView + sidebar + engine status
    ├── DashboardView.swift     Summary cards, error/engine banners
    ├── ContainersListView.swift  Filterable table + quick actions
    ├── StacksView.swift        Compose import + stack orchestration
    ├── ContainerDetailView.swift Overview / Logs / Inspector + shell
    ├── LogViewer.swift         Live streaming, filter, copy
    ├── MultiLogView.swift      Combined logs of many containers, color-coded
    ├── NetworksView.swift      List/create/delete container networks
    ├── ImagesView.swift        List + pull + delete images
    ├── VolumesView.swift       List + create + delete volumes
    ├── SettingsView.swift      CLI path, language, theme, polling, demo, diagnostics
    └── Components.swift        StatusBadge, StatCard, menus, banners
```

Principles:

- **Everything goes through the `ContainerEngine` protocol**: the UI never
  talks to the CLI directly. When apple/container ships stable XPC/library
  APIs, a new protocol implementation is all that's needed.
- **Tolerant JSON parsing**: the `--format json` schema is not a stable
  contract across releases; every field is looked up through multiple paths
  and degrades to "—" instead of breaking. The *Inspector* tab always shows
  the raw JSON for debugging.
- **One external dependency**: [Yams](https://github.com/jpsim/Yams) for
  YAML parsing (Stacks feature) — everything else is SwiftUI, Foundation
  and Observation.

## Localization

The UI ships in **English (default) and Italian**, switchable live from
Settings → Interface → Language, with no restart. Strings go through a tiny
`L()`/`LF()` layer (`Services/Localization.swift`); adding a language means
adding one dictionary.

## Known limitations (v0.1)

- JSON schemas are verified against CLI **1.0.0**; future versions may need
  new fallback paths in the models.
- The CPU percentage is derived from the `cpuUsageUsec` delta between two
  samples: the first refresh after startup shows "—".
- The integrated shell opens Terminal.app via AppleScript (requires the
  Automation permission on first use); an embedded terminal is on the roadmap.
- No automatic updates yet (Sparkle is on the roadmap).
