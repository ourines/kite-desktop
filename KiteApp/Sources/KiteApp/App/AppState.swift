import Foundation
import Combine

/// Central application state shared via @EnvironmentObject.
final class AppState: ObservableObject {
    // MARK: – Active cluster
    @Published var currentClusterID: Int? {
        didSet { UserDefaults.standard.set(currentClusterID, forKey: "currentClusterID") }
    }

    // MARK: – Navigation / overlay triggers
    @Published var showAddCluster = false
    @Published var showGlobalSearch = false
    @Published var showAIChat = false

    // MARK: – Appearance
    @Published var colorScheme: ColorSchemePreference {
        didSet { UserDefaults.standard.set(colorScheme.rawValue, forKey: "colorScheme") }
    }

    init() {
        currentClusterID = UserDefaults.standard.value(forKey: "currentClusterID") as? Int
        let raw = UserDefaults.standard.string(forKey: "colorScheme") ?? ""
        colorScheme = ColorSchemePreference(rawValue: raw) ?? .system
    }
}

enum ColorSchemePreference: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}
