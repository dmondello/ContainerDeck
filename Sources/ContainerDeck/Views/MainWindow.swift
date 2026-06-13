import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case containers = "Container"
    case stacks = "Stack"
    case images = "Immagini"
    case volumes = "Volumi"
    case networks = "Reti"
    case settings = "Impostazioni"

    var id: String { rawValue }

    /// Etichetta localizzata (il rawValue resta l'identificatore stabile).
    var title: String { L(rawValue) }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.50percent"
        case .containers: return "shippingbox"
        case .stacks: return "square.stack.3d.up"
        case .images: return "opticaldisc"
        case .volumes: return "externaldrive"
        case .networks: return "network"
        case .settings: return "gearshape"
        }
    }
}

struct MainWindow: View {
    @Environment(AppState.self) private var appState
    @State private var selection: SidebarSection? = .dashboard
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            NavigationStack {
                switch selection ?? .dashboard {
                case .dashboard: DashboardView()
                case .containers: ContainersListView()
                case .stacks: StacksView()
                case .images: ImagesView()
                case .volumes: VolumesView()
                case .networks: NetworksView()
                case .settings: SettingsView()
                }
            }
        }
        .preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    /// Wordmark dell'app in testa alla sidebar: icona su gradiente
    /// blu→teal e "Deck" sfumato in tinta.
    private var brandHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(LinearGradient(colors: [.blue, .teal],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                    .shadow(color: .teal.opacity(0.35), radius: 5, y: 2)
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                (Text("Container").foregroundStyle(.primary)
                 + Text("Deck").foregroundStyle(
                    LinearGradient(colors: [.blue, .teal],
                                   startPoint: .leading,
                                   endPoint: .trailing)))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(L("GUI per apple/container"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 22)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            brandHeader
            List(selection: $selection) {
                Section {
                    ForEach(SidebarSection.allCases) { section in
                        Label {
                            HStack {
                                Text(section.title)
                                if section == .containers, appState.runningCount > 0 {
                                    Spacer()
                                    Text("\(appState.runningCount)")
                                        .font(.caption2.monospacedDigit())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(.green.opacity(0.2), in: Capsule())
                                        .foregroundStyle(.green)
                                }
                            }
                        } icon: {
                            Image(systemName: section.icon)
                        }
                        .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()
            engineFooter
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
    }

    private var engineFooter: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(engineColor)
                .frame(width: 9, height: 9)
            Text(appState.engineStatus.label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            if appState.engineStatus == .stopped {
                Button(L("Avvia")) {
                    Task { await appState.startEngine() }
                }
                .controlSize(.small)
            }
        }
        .padding(10)
    }

    private var engineColor: Color {
        switch appState.engineStatus {
        case .running: return .green
        case .stopped: return .orange
        case .notInstalled: return .red
        case .unknown: return .gray
        }
    }
}
