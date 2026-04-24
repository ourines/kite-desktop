import Foundation

// MARK: – Cluster

struct Cluster: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var description: String?
    var version: String?
    var config: String?
    var enabled: Bool
    var inCluster: Bool
    var isDefault: Bool
    let createdAt: String
    let updatedAt: String
    var prometheusURL: String?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, version, config, enabled
        case inCluster, isDefault, createdAt, updatedAt
        case prometheusURL, error
    }
}

// MARK: – Cluster request/response DTOs

struct ClusterCreateRequest: Codable {
    var name: String
    var description: String?
    var config: String?
    var inCluster: Bool
    var prometheusURL: String?
}

struct ClusterUpdateRequest: Codable {
    var name: String
    var description: String?
    var config: String?
    var enabled: Bool
    var prometheusURL: String?
}

struct ClusterTestRequest: Codable {
    var config: String
}

struct ClusterTestResponse: Codable {
    var success: Bool
    var message: String
    var version: String?
}

struct ImportKubeconfigRequest: Codable {
    var kubeconfig: String
}

// MARK: – Overview

struct OverviewData: Codable {
    var totalNodes: Int
    var readyNodes: Int
    var totalPods: Int
    var runningPods: Int
    var totalNamespaces: Int
    var totalServices: Int
    var prometheusEnabled: Bool
    var resource: ResourceCapacity
}

struct ResourceCapacity: Codable {
    var cpu: CPUCapacity
    var memory: MemoryCapacity
}

struct CPUCapacity: Codable {
    var allocatable: Double
    var requested: Double
    var limited: Double
}

struct MemoryCapacity: Codable {
    var allocatable: Double
    var requested: Double
    var limited: Double
}

// MARK: – Usage history (Prometheus)

struct UsageDataPoint: Codable, Identifiable {
    var timestamp: String
    var value: Double
    var id: String { timestamp }
}

struct ResourceUsageHistory: Codable {
    var cpu: [UsageDataPoint]
    var memory: [UsageDataPoint]
    var networkIn: [UsageDataPoint]
    var networkOut: [UsageDataPoint]
    var diskRead: [UsageDataPoint]
    var diskWrite: [UsageDataPoint]
}

// MARK: – Recent event (overview)

struct RecentEvent: Codable, Identifiable {
    var type: String
    var reason: String
    var message: String
    var involvedObjectKind: String
    var involvedObjectName: String
    var namespace: String?
    var timestamp: String
    var id: String { "\(timestamp)-\(involvedObjectName)-\(reason)" }
}

// MARK: – Search

struct SearchResult: Codable, Identifiable {
    var id: String
    var name: String
    var namespace: String?
    var resourceType: String
    var createdAt: String
}

struct SearchResponse: Codable {
    var results: [SearchResult]
    var total: Int
}

// MARK: – Resource template

struct ResourceTemplate: Codable, Identifiable {
    var ID: Int
    var name: String
    var description: String
    var yaml: String
    var id: Int { ID }
}

// MARK: – Favorites

struct FavoriteResource: Codable, Identifiable {
    var id: Int
    var clusterName: String
    var resourceType: String
    var namespace: String?
    var resourceName: String
    var createdAt: String
    var updatedAt: String
}

struct FavoriteResourceRequest: Codable {
    var resourceType: String
    var namespace: String?
    var resourceName: String
}

// MARK: – Apply resource

struct ApplyResourceRequest: Codable {
    var yaml: String
}

struct ApplyResourceResponse: Codable {
    var message: String
    var kind: String
    var name: String
    var namespace: String?
}

// MARK: – Version

struct VersionInfo: Codable {
    var version: String
    var buildTime: String?
    var gitCommit: String?
}

struct CheckUpdateResponse: Codable {
    var comparison: String   // "latest", "update_available", "unknown"
    var latestVersion: String?
    var currentVersion: String?
}

// MARK: – General Settings (AI)

struct GeneralSetting: Codable {
    var aiEnabled: Bool
    var aiProvider: String
    var aiBaseURL: String
    var aiModel: String
    var aiAPIKey: String
}
