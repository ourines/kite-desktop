import Foundation
import SwiftData

// MARK: – ClusterStore: bridges local SwiftData with remote backend data

@MainActor
final class ClusterStore: ObservableObject {
    @Published var clusters: [Cluster] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let api = APIClient.shared

    // MARK: – Load from remote

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            clusters = try await api.getClusters()
        } catch {
            self.error = error
        }
    }

    func create(_ req: ClusterCreateRequest) async throws -> Cluster {
        let cluster = try await api.createCluster(req)
        clusters.append(cluster)
        return cluster
    }

    func update(id: Int, req: ClusterUpdateRequest) async throws -> Cluster {
        let updated = try await api.updateCluster(id: id, req: req)
        if let idx = clusters.firstIndex(where: { $0.id == id }) {
            clusters[idx] = updated
        }
        return updated
    }

    func delete(id: Int) async throws {
        try await api.deleteCluster(id: id)
        clusters.removeAll { $0.id == id }
    }

    func testConnection(config: String) async throws -> ClusterTestResponse {
        return try await api.testCluster(ClusterTestRequest(config: config))
    }

    func importKubeconfig(_ raw: String) async throws -> [Cluster] {
        let imported = try await api.importKubeconfig(ImportKubeconfigRequest(kubeconfig: raw))
        clusters = try await api.getClusters()
        return imported
    }
}

// MARK: – FavoritesStore

@MainActor
final class FavoritesStore: ObservableObject {
    @Published var favorites: [FavoriteResource] = []

    private let api = APIClient.shared

    func load() async {
        do { favorites = try await api.getFavorites() } catch {}
    }

    func add(resourceType: String, namespace: String?, resourceName: String) async throws {
        let req = FavoriteResourceRequest(resourceType: resourceType, namespace: namespace, resourceName: resourceName)
        let fav = try await api.addFavorite(req)
        favorites.append(fav)
    }

    func remove(resourceType: String, namespace: String?, resourceName: String) async throws {
        let req = FavoriteResourceRequest(resourceType: resourceType, namespace: namespace, resourceName: resourceName)
        try await api.removeFavorite(req)
        favorites.removeAll { $0.resourceType == resourceType && $0.resourceName == resourceName && $0.namespace == namespace }
    }

    func isFavorite(resourceType: String, namespace: String?, resourceName: String) -> Bool {
        favorites.contains { $0.resourceType == resourceType && $0.resourceName == resourceName && $0.namespace == namespace }
    }
}
