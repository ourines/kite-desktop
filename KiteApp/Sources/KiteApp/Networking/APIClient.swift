import Foundation

// MARK: – API error

enum APIError: LocalizedError {
    case invalidURL
    case noClusterSelected
    case httpError(Int, String)
    case decodingError(Error)
    case networkError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid URL"
        case .noClusterSelected:    return "No cluster selected"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        case .decodingError(let e): return "Decoding error: \(e.localizedDescription)"
        case .networkError(let e):  return e.localizedDescription
        case .unknown:              return "Unknown error"
        }
    }
}

// MARK: – Server configuration stored per-connection (not the same as SwiftData Cluster)

struct ServerConnection {
    let baseURL: URL
    let clusterName: String?

    /// Build a full URL for an API path like "/api/v1/pods/default"
    func url(path: String) throws -> URL {
        guard
            let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
            var urlComponents = URLComponents(string: components.string ?? baseURL.absoluteString)
        else {
            throw APIError.invalidURL
        }
        urlComponents.path = (urlComponents.path.hasSuffix("/") ? String(urlComponents.path.dropLast()) : urlComponents.path) + "/api/v1" + path
        guard let url = urlComponents.url else { throw APIError.invalidURL }
        return url
    }

    /// Build a URL for non-versioned paths (e.g. /healthz)
    func rawURL(path: String) throws -> URL {
        guard
            var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        else { throw APIError.invalidURL }
        comps.path = path
        guard let url = comps.url else { throw APIError.invalidURL }
        return url
    }
}

// MARK: – APIClient

actor APIClient {
    static let shared = APIClient()

    private(set) var connection: ServerConnection?
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 30
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
    }

    // MARK: – Configuration

    func configure(baseURL: URL, clusterName: String? = nil) {
        connection = ServerConnection(baseURL: baseURL, clusterName: clusterName)
    }

    // MARK: – Low-level request helpers

    private func makeRequest(method: String, path: String, body: Data? = nil) throws -> URLRequest {
        guard let conn = connection else { throw APIError.noClusterSelected }
        let url = try conn.url(path: path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let clusterName = conn.clusterName {
            req.setValue(clusterName, forHTTPHeaderField: "x-cluster-name")
        }
        req.httpBody = body
        return req
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(http.statusCode, msg)
        }
        do {
            return try JSONDecoder.k8s.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: – Public CRUD methods

    func get<T: Decodable>(_ path: String) async throws -> T {
        let req = try makeRequest(method: "GET", path: path)
        return try await execute(req)
    }

    func post<T: Decodable>(_ path: String, body: Encodable? = nil) async throws -> T {
        let data = try body.map { try JSONEncoder.k8s.encode($0) }
        let req  = try makeRequest(method: "POST", path: path, body: data)
        return try await execute(req)
    }

    func put<T: Decodable>(_ path: String, body: Encodable) async throws -> T {
        let data = try JSONEncoder.k8s.encode(body)
        let req  = try makeRequest(method: "PUT", path: path, body: data)
        return try await execute(req)
    }

    func patch<T: Decodable>(_ path: String, body: Encodable) async throws -> T {
        let data = try JSONEncoder.k8s.encode(body)
        var req  = try makeRequest(method: "PATCH", path: path, body: data)
        req.setValue("application/merge-patch+json", forHTTPHeaderField: "Content-Type")
        return try await execute(req)
    }

    func delete(_ path: String) async throws {
        let req = try makeRequest(method: "DELETE", path: path)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(http.statusCode, msg)
        }
    }

    // MARK: – Raw data (for YAML download etc.)

    func getRawData(_ path: String) async throws -> Data {
        let req = try makeRequest(method: "GET", path: path)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(http.statusCode, msg)
        }
        return data
    }

    // MARK: – WebSocket URL builder

    func webSocketURL(path: String) throws -> URL {
        guard let conn = connection else { throw APIError.noClusterSelected }
        let httpURL = try conn.url(path: path)
        guard var components = URLComponents(url: httpURL, resolvingAgainstBaseURL: true) else {
            throw APIError.invalidURL
        }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        guard let wsURL = components.url else { throw APIError.invalidURL }
        return wsURL
    }
}

// MARK: – JSON coder helpers

extension JSONDecoder {
    static let k8s: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys   // K8s JSON already uses camelCase
        return d
    }()
}

extension JSONEncoder {
    static let k8s: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .useDefaultKeys
        return e
    }()
}
