import SwiftUI

/// Bootstrap view: configures the API client from UserDefaults, then shows
/// the server setup sheet if no URL is saved yet.
struct AppEntryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isReady = false
    @State private var showServerSetup = false

    var body: some View {
        Group {
            if isReady {
                RootView()
            } else {
                ProgressView("Connecting…")
            }
        }
        .sheet(isPresented: $showServerSetup, onDismiss: {
            // After setup, try again
            Task { await configure() }
        }) {
            ServerSetupView()
        }
        .task { await configure() }
    }

    private func configure() async {
        if let saved = UserDefaults.standard.string(forKey: "serverBaseURL"),
           let url = URL(string: saved) {
            await APIClient.shared.configure(baseURL: url)
            isReady = true
        } else {
            showServerSetup = true
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        Group {
#if targetEnvironment(macCatalyst)
            SplitRootView()
#else
            if hSizeClass == .regular {
                SplitRootView()
            } else {
                TabRootView()
            }
#endif
        }
        .sheet(isPresented: $appState.showGlobalSearch) {
            GlobalSearchView()
        }
        .sheet(isPresented: $appState.showAIChat) {
            AIChatView()
        }
        .preferredColorScheme(appState.colorScheme.swiftUIColorScheme)
    }
}

// MARK: – iPad / Mac: NavigationSplitView three-column layout
private struct SplitRootView: View {
    @State private var selectedNavItem: SidebarItem? = .overview
    @State private var selectedResource: ResourceNavTarget?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedNavItem)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } content: {
            contentForSelection(selectedNavItem)
                .navigationSplitViewColumnWidth(min: 300, ideal: 380)
        } detail: {
            if let target = selectedResource {
                ResourceDetailView(target: target)
            } else {
                Text("Select a resource")
                    .foregroundStyle(.secondary)
            }
        }
        .environment(\.resourceSelectionHandler, ResourceSelectionHandler { target in
            selectedResource = target
        })
    }

    @ViewBuilder
    private func contentForSelection(_ item: SidebarItem?) -> some View {
        switch item {
        case .overview, .none:
            OverviewView()
        case .favorites:
            FavoritesView()
        case .resource(let kind):
            ResourceListView(resourceKind: kind)
        case .settings:
            SettingsView()
        }
    }
}

// MARK: – iPhone: TabView + NavigationStack
private struct TabRootView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                OverviewView()
                    .navigationTitle("Overview")
            }
            .tabItem { Label("Overview", systemImage: "square.grid.2x2") }
            .tag(0)

            NavigationStack {
                SidebarMenuView()
                    .navigationTitle("Resources")
            }
            .tabItem { Label("Resources", systemImage: "server.rack") }
            .tag(1)

            NavigationStack {
                FavoritesView()
                    .navigationTitle("Favorites")
            }
            .tabItem { Label("Favorites", systemImage: "star") }
            .tag(2)

            NavigationStack {
                AIChatView()
                    .navigationTitle("AI Assistant")
            }
            .tabItem { Label("AI", systemImage: "sparkles") }
            .tag(3)

            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
            }
            .tabItem { Label("Settings", systemImage: "gear") }
            .tag(4)
        }
    }
}

// MARK: – ColorScheme helper
extension ColorSchemePreference {
    var swiftUIColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: – Environment key for resource selection
struct ResourceSelectionHandler {
    let select: (ResourceNavTarget) -> Void
}

private struct ResourceSelectionKey: EnvironmentKey {
    static let defaultValue = ResourceSelectionHandler { _ in }
}

extension EnvironmentValues {
    var resourceSelectionHandler: ResourceSelectionHandler {
        get { self[ResourceSelectionKey.self] }
        set { self[ResourceSelectionKey.self] = newValue }
    }
}
