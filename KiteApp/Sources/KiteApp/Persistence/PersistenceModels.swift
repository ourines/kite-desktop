import Foundation
import SwiftData

// MARK: – Persisted cluster connection (SwiftData model)

@Model
final class PersistedCluster {
    var serverID: Int       // ID from the backend
    var name: String
    var baseURL: String     // e.g. "http://192.168.1.100:9090"
    var isDefault: Bool
    var addedAt: Date

    init(serverID: Int, name: String, baseURL: String, isDefault: Bool = false) {
        self.serverID = serverID
        self.name     = name
        self.baseURL  = baseURL
        self.isDefault = isDefault
        self.addedAt  = Date()
    }
}

// MARK: – Persisted favorite

@Model
final class PersistedFavorite {
    var favoriteID: Int
    var clusterName: String
    var resourceType: String
    var namespace: String?
    var resourceName: String
    var addedAt: Date

    init(remote: FavoriteResource) {
        favoriteID   = remote.id
        clusterName  = remote.clusterName
        resourceType = remote.resourceType
        namespace    = remote.namespace
        resourceName = remote.resourceName
        addedAt      = Date()
    }
}

// MARK: – Persisted search history entry

@Model
final class SearchHistoryEntry {
    var query: String
    var searchedAt: Date

    init(query: String) {
        self.query      = query
        self.searchedAt = Date()
    }
}

// MARK: – Container setup

extension ModelContainer {
    static let kite: ModelContainer = {
        let schema = Schema([
            PersistedCluster.self,
            PersistedFavorite.self,
            SearchHistoryEntry.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Fall back to in-memory store so the app can still run if the on-disk
            // store is corrupted.  In a production app you might want to present an
            // error to the user or attempt migration first.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback]) // swiftlint:disable:this force_try
        }
    }()
}
