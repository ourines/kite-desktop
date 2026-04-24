import SwiftUI

@main
struct KiteApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
#if targetEnvironment(macCatalyst)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Clusters") {
                Button("Add Cluster…") {
                    appState.showAddCluster = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandMenu("View") {
                Button("Global Search") {
                    appState.showGlobalSearch = true
                }
                .keyboardShortcut("k", modifiers: .command)
                Button("AI Assistant") {
                    appState.showAIChat = true
                }
                .keyboardShortcut("j", modifiers: [.command, .shift])
            }
        }
#endif
    }
}
