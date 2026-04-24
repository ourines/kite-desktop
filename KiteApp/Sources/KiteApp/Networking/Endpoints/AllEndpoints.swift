import Foundation

// MARK: – Cluster endpoints

extension APIClient {

    // Admin cluster management
    func getClusters() async throws -> [Cluster] {
        return try await get("/admin/clusters/")
    }

    func createCluster(_ req: ClusterCreateRequest) async throws -> Cluster {
        return try await post("/admin/clusters/", body: req)
    }

    func updateCluster(id: Int, req: ClusterUpdateRequest) async throws -> Cluster {
        return try await put("/admin/clusters/\(id)", body: req)
    }

    func deleteCluster(id: Int) async throws {
        try await delete("/admin/clusters/\(id)")
    }

    func testCluster(_ req: ClusterTestRequest) async throws -> ClusterTestResponse {
        return try await post("/admin/clusters/test", body: req)
    }

    func importKubeconfig(_ req: ImportKubeconfigRequest) async throws -> [Cluster] {
        return try await post("/admin/clusters/import", body: req)
    }

    // Current accessible clusters (for the cluster selector)
    func getAccessibleClusters() async throws -> [Cluster] {
        return try await get("/clusters")
    }
}

// MARK: – Overview & Observability

extension APIClient {

    func getOverview() async throws -> OverviewData {
        return try await get("/overview")
    }

    func getResourceUsageHistory(timeRange: String = "30m") async throws -> ResourceUsageHistory {
        return try await get("/prometheus/resource-usage-history?timeRange=\(timeRange)")
    }

    func getPodMetrics(namespace: String, podName: String, timeRange: String = "30m") async throws -> PodMonitoringMetrics {
        return try await get("/prometheus/pods/\(namespace)/\(podName)/metrics?timeRange=\(timeRange)")
    }
}

// MARK: – Generic resource CRUD

extension APIClient {

    func listResources<T: Decodable>(
        kind: String,
        namespace: String? = nil,
        limit: Int? = nil,
        continueToken: String? = nil,
        labelSelector: String? = nil,
        fieldSelector: String? = nil
    ) async throws -> T {
        var path = "/" + kind
        if let ns = namespace { path += "/\(ns)" }
        var params: [String] = []
        if let l = limit           { params.append("limit=\(l)") }
        if let c = continueToken   { params.append("continue=\(c)") }
        if let l = labelSelector   { params.append("labelSelector=\(l)") }
        if let f = fieldSelector   { params.append("fieldSelector=\(f)") }
        if !params.isEmpty         { path += "?" + params.joined(separator: "&") }
        return try await get(path)
    }

    func getResource<T: Decodable>(kind: String, namespace: String?, name: String) async throws -> T {
        let ns = namespace ?? "_all"
        return try await get("/\(kind)/\(ns)/\(name)")
    }

    func describeResource(kind: String, namespace: String?, name: String) async throws -> String {
        let ns = namespace ?? "_all"
        let resp: [String: String] = try await get("/\(kind)/\(ns)/\(name)/describe")
        return resp["result"] ?? ""
    }

    func deleteResource(kind: String, namespace: String?, name: String, force: Bool = false) async throws {
        var path = "/\(kind)/\(namespace ?? "_all")/\(name)"
        if force { path += "?force=true" }
        try await delete(path)
    }

    func applyResource(yaml: String) async throws -> ApplyResourceResponse {
        return try await post("/resources/apply", body: ApplyResourceRequest(yaml: yaml))
    }

    func getResourceHistory(kind: String, namespace: String, name: String, page: Int = 1, pageSize: Int = 10) async throws -> ResourceHistoryResponse {
        return try await get("/\(kind)/\(namespace)/\(name)/history?page=\(page)&pageSize=\(pageSize)")
    }

    func getRelatedResources(kind: String, namespace: String, name: String) async throws -> [RelatedResource] {
        return try await get("/\(kind)/\(namespace)/\(name)/related")
    }
}

// MARK: – Pod-specific

extension APIClient {

    func listPodFiles(namespace: String, podName: String, container: String, path: String) async throws -> [FileInfo] {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
        return try await get("/pods/\(namespace)/\(podName)/files?container=\(container)&path=\(encoded)")
    }

    func downloadPodFile(namespace: String, podName: String, container: String, path: String) async throws -> Data {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
        return try await getRawData("/pods/\(namespace)/\(podName)/files/download?container=\(container)&path=\(encoded)")
    }

    func logsWebSocketURL(namespace: String, podName: String) throws -> URL {
        return try webSocketURL(path: "/logs/\(namespace)/\(podName)/ws")
    }

    func terminalWebSocketURL(namespace: String, podName: String) throws -> URL {
        return try webSocketURL(path: "/terminal/\(namespace)/\(podName)/ws")
    }

    func nodeTerminalWebSocketURL(nodeName: String) throws -> URL {
        return try webSocketURL(path: "/node-terminal/\(nodeName)/ws")
    }

    func kubectlTerminalWebSocketURL() throws -> URL {
        return try webSocketURL(path: "/kubectl-terminal/ws")
    }
}

// MARK: – Search & Favorites

extension APIClient {

    func globalSearch(query: String, limit: Int = 50, namespace: String? = nil) async throws -> SearchResponse {
        var path = "/search?q=\(query.urlEncoded)&limit=\(limit)"
        if let ns = namespace { path += "&namespace=\(ns)" }
        return try await get(path)
    }

    func getFavorites() async throws -> [FavoriteResource] {
        return try await get("/preferences/favorites")
    }

    func addFavorite(_ req: FavoriteResourceRequest) async throws -> FavoriteResource {
        return try await post("/preferences/favorites", body: req)
    }

    func removeFavorite(_ req: FavoriteResourceRequest) async throws {
        let _: EmptyResponse = try await post("/preferences/favorites/remove", body: req)
    }
}

// MARK: – Templates

extension APIClient {

    func listTemplates() async throws -> [ResourceTemplate] {
        return try await get("/templates/")
    }

    func createTemplate(_ t: ResourceTemplate) async throws -> ResourceTemplate {
        return try await post("/admin/templates/", body: t)
    }

    func updateTemplate(id: Int, _ t: ResourceTemplate) async throws -> ResourceTemplate {
        return try await put("/admin/templates/\(id)", body: t)
    }

    func deleteTemplate(id: Int) async throws {
        try await delete("/admin/templates/\(id)")
    }
}

// MARK: – Settings

extension APIClient {

    func getGeneralSetting() async throws -> GeneralSetting {
        return try await get("/settings/general")
    }

    func updateGeneralSetting(_ s: GeneralSetting) async throws -> GeneralSetting {
        return try await put("/settings/general", body: s)
    }
}

// MARK: – Version

extension APIClient {

    func getVersion() async throws -> VersionInfo {
        return try await get("/version")
    }

    func checkUpdate() async throws -> CheckUpdateResponse {
        return try await post("/version/check-update")
    }
}

// MARK: – AI

extension APIClient {

    func aiStatus() async throws -> AIStatus {
        return try await get("/ai/status")
    }

    func aiChat(_ req: AIChatRequest) async throws -> AIChatResponse {
        return try await post("/ai/chat", body: req)
    }

    func aiExecuteContinue(_ req: ExecuteContinueRequest) async throws -> AIChatResponse {
        return try await post("/ai/execute/continue", body: req)
    }

    func aiInputContinue(_ req: InputContinueRequest) async throws -> AIChatResponse {
        return try await post("/ai/input/continue", body: req)
    }

    func listAISessions() async throws -> [AISession] {
        return try await get("/ai/sessions")
    }

    func getAISession(id: String) async throws -> AISession {
        return try await get("/ai/sessions/\(id)")
    }

    func upsertAISession(_ session: AISession) async throws -> AISession {
        return try await put("/ai/sessions/\(session.id)", body: session)
    }

    func deleteAISession(id: String) async throws {
        try await delete("/ai/sessions/\(id)")
    }
}

// MARK: – Node operations

extension APIClient {

    func cordonNode(name: String) async throws {
        let _: AnyCodable = try await post("/nodes/_all/\(name)/cordon")
    }

    func uncordonNode(name: String) async throws {
        let _: AnyCodable = try await post("/nodes/_all/\(name)/uncordon")
    }

    func drainNode(name: String) async throws {
        struct DrainOptions: Codable {
            var force = true; var gracePeriod = -1
            var deleteLocalData = true; var ignoreDaemonsets = true
        }
        let _: AnyCodable = try await post("/nodes/_all/\(name)/drain", body: DrainOptions())
    }
}

// MARK: – Deployment scale

extension APIClient {

    func scaleDeployment(namespace: String, name: String, replicas: Int) async throws {
        struct ScaleBody: Codable { var replicas: Int }
        let _: AnyCodable = try await put("/deployments/\(namespace)/\(name)/scale", body: ScaleBody(replicas: replicas))
    }
}

// MARK: – Helpers

private struct EmptyResponse: Codable {}

extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
