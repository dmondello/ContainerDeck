# Changelog

All notable changes to ContainerDeck are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/), and the project follows
semantic-ish versioning while pre-1.0.

## [0.5.0] — 2026-06-13

### Added
- **Built-in terminal**: the container "Shell" now opens an in-app PTY
  terminal (SwiftTerm) running `container exec`, instead of handing off to
  Terminal.app — which remains available as a secondary option.

### Changed
- Stack service discovery (`/etc/hosts`) is re-applied automatically when a
  stack member is restarted on its own, since its IP may change.

### Dependencies
- Added [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm).

## [0.4.1] — 2026-06-13

### Added
- **Dependency-free test suite** (56 assertions) runnable with the Command
  Line Tools alone via `make test` / `ContainerDeck --run-tests`, exiting
  non-zero on failure. Covers JSON access, model mappings against the CLI
  1.0.0 schema, run-argument generation, and the compose parser.

## [0.4.0] — 2026-06-13

### Added
- **Combined multi-container log viewer**: one `logs --follow` stream per
  container merged into a single color-coded view, with per-container
  show/hide toggles, text filter, copy and autoscroll. Opened from the
  Containers toolbar (all running containers) or a stack's toolbar (all
  running services).
- **Networks** section: list networks (subnet, gateway, mode) and the
  containers on each, create and delete via `container network`. The built-in
  `default` network is protected; listing degrades cleanly on macOS 15.

## [0.3.0] — 2026-06-13

### Added
- **Stacks service discovery**: after a stack starts, each service's IP is
  injected into the other containers' `/etc/hosts`, so compose references
  (`db`, `http://superset:8088`) resolve by name.

### Changed
- Stack containers are named by their plain service name (so unmodified
  compose references resolve).

### Notes
- Empirical testing showed apple/container 1.0.0 has **no** inter-container
  name resolution — not on the default network, not on a custom one, and
  `container system dns create` only covers container→host. The DNS-domain
  approach briefly prototyped in 0.2.x was therefore replaced with the
  verified `/etc/hosts` method.

## [0.2.0] — 2026-06-12

### Added
- **Stacks**: import a `docker-compose.yml` and orchestrate it on the runtime.
  Supports `services` (image / build / command / ports / environment /
  volumes / depends_on), top-level named volumes, and `${VAR:-default}`
  interpolation from `.env` and the process environment. Start order follows
  `depends_on`; builds run through `container build`. `restart`,
  `healthcheck` and system socket mounts are skipped with explicit warnings.
- Yams as the only external dependency (YAML parsing).
- `--parse-compose <file>` debug hook.

## [0.1.0] — 2026-06-11

### Added
- First release. Dashboard (running/stopped counts, CPU, memory, disk).
- Container management: create, start, stop, restart, delete, with guided
  first-run kernel setup.
- Container detail: configuration, live resource stats, mounted volumes,
  environment variables, raw JSON inspector.
- Live per-container log viewer (follow, filter, copy).
- Images: pull from OCI registries, delete, create container via right-click.
- Volumes: create, delete, see which containers use them.
- Open container IPs in browser / VNC / FTP; shell into containers via Terminal.
- English/Italian interface with live switching, light/dark theme, Demo mode.
- App icon, Makefile targets for `.app` bundle and DMG packaging.

[0.5.0]: https://github.com/dmondello/ContainerDeck/releases/tag/v0.5.0
[0.4.1]: https://github.com/dmondello/ContainerDeck/releases/tag/v0.4.1
[0.4.0]: https://github.com/dmondello/ContainerDeck/releases/tag/v0.4.0
[0.3.0]: https://github.com/dmondello/ContainerDeck/releases/tag/v0.3.0
[0.2.0]: https://github.com/dmondello/ContainerDeck/releases/tag/v0.2.0
[0.1.0]: https://github.com/dmondello/ContainerDeck/releases/tag/v0.1.0
