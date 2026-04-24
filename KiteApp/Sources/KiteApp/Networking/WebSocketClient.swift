import Foundation

// MARK: – WebSocket message

enum WSMessage {
    case text(String)
    case data(Data)
    case error(Error)
    case disconnected
}

// MARK: – WebSocketClient

final class WebSocketClient: NSObject, URLSessionWebSocketDelegate {
    private var task: URLSessionWebSocketTask?
    private let session: URLSession
    var onMessage: ((WSMessage) -> Void)?
    var onConnect: (() -> Void)?

    override init() {
        session = URLSession(configuration: .default)
        super.init()
    }

    // MARK: – Connect

    func connect(to url: URL, clusterName: String? = nil) {
        disconnect()
        var request = URLRequest(url: url)
        if let clusterName {
            request.setValue(clusterName, forHTTPHeaderField: "x-cluster-name")
        }
        task = session.webSocketTask(with: request)
        task?.delegate = self
        task?.resume()
        scheduleReceive()
        onConnect?()
    }

    // MARK: – Send

    func send(_ text: String) {
        task?.send(.string(text)) { _ in }
    }

    func send(_ data: Data) {
        task?.send(.data(data)) { _ in }
    }

    // MARK: – Disconnect

    func disconnect() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }

    // MARK: – Receive loop

    private func scheduleReceive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let msg):
                switch msg {
                case .string(let text): self.onMessage?(.text(text))
                case .data(let data):   self.onMessage?(.data(data))
                @unknown default: break
                }
                self.scheduleReceive()
            case .failure(let error):
                self.onMessage?(.error(error))
            }
        }
    }

    // MARK: – URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        onMessage?(.disconnected)
    }
}
