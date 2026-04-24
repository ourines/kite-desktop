import SwiftUI

// MARK: – Pod logs view

struct PodLogsView: View {
    let namespace: String
    let podName: String
    let containers: [String]

    @State private var selectedContainer: String = ""
    @State private var logLines: [String] = []
    @State private var wsClient = WebSocketClient()
    @State private var isConnected = false
    @State private var tailLines = 100
    @State private var input = ""
    @State private var wsURL: URL?
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Picker("Container", selection: $selectedContainer) {
                    ForEach(containers, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Spacer()

                HStack {
                    Circle().fill(isConnected ? Color.k8sGreen : Color.k8sRed)
                        .frame(width: 8, height: 8)
                    Text(isConnected ? "Live" : "Disconnected").font(.caption)
                }

                Button {
                    reconnect()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.background.secondary)

            Divider()

            // Log output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(logLines.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.green)
                                .textSelection(.enabled)
                                .id(idx)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(red: 0.08, green: 0.08, blue: 0.12))
                .onChange(of: logLines.count) { _, _ in
                    proxy.scrollTo(logLines.count - 1, anchor: .bottom)
                }
            }
        }
        .navigationTitle("Logs – \(podName)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedContainer.isEmpty { selectedContainer = containers.first ?? "" }
            reconnect()
        }
        .onChange(of: selectedContainer) { _, _ in reconnect() }
        .onDisappear { wsClient.disconnect() }
    }

    private func reconnect() {
        logLines = []
        wsClient.disconnect()
        Task {
            guard let url = try? await APIClient.shared.logsWebSocketURL(namespace: namespace, podName: podName) else { return }
            // Append container and tail params
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: true)!
            var items = comps.queryItems ?? []
            items.append(URLQueryItem(name: "container", value: selectedContainer))
            items.append(URLQueryItem(name: "tailLines", value: "\(tailLines)"))
            items.append(URLQueryItem(name: "follow", value: "true"))
            comps.queryItems = items
            guard let finalURL = comps.url else { return }

            wsClient.onMessage = { msg in
                if case .text(let line) = msg {
                    DispatchQueue.main.async { logLines.append(line) }
                }
            }
            wsClient.onConnect = { DispatchQueue.main.async { isConnected = true } }
            wsClient.connect(to: finalURL)
        }
    }
}

// MARK: – Pod terminal view

struct PodTerminalView: View {
    let namespace: String
    let podName: String
    let containers: [String]

    @State private var selectedContainer: String = ""
    @State private var input = ""
    @State private var wsURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Container", selection: $selectedContainer) {
                    ForEach(containers, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.background.secondary)

            Divider()

            if let url = wsURL {
                TerminalView(webSocketURL: url, input: $input)
            } else {
                Color(red: 0.08, green: 0.08, blue: 0.12)
                    .overlay { ProgressView() }
            }
        }
        .navigationTitle("Terminal – \(podName)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedContainer.isEmpty { selectedContainer = containers.first ?? "" }
            buildURL()
        }
        .onChange(of: selectedContainer) { _, _ in buildURL() }
    }

    private func buildURL() {
        Task {
            guard let url = try? await APIClient.shared.terminalWebSocketURL(namespace: namespace, podName: podName) else { return }
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: true)!
            comps.queryItems = [URLQueryItem(name: "container", value: selectedContainer)]
            wsURL = comps.url
        }
    }
}

// MARK: – Pod file browser

@MainActor
final class PodFileBrowserViewModel: ObservableObject {
    @Published var files: [FileInfo] = []
    @Published var currentPath = "/"
    @Published var isLoading = false
    @Published var error: Error?

    let namespace: String
    let podName: String
    let container: String
    private let api = APIClient.shared

    init(namespace: String, podName: String, container: String) {
        self.namespace = namespace
        self.podName   = podName
        self.container = container
    }

    func list(path: String = "/") async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            files = try await api.listPodFiles(namespace: namespace, podName: podName, container: container, path: path)
            currentPath = path
        } catch {
            self.error = error
        }
    }

    func navigate(to name: String, isDir: Bool) async {
        let newPath = currentPath.hasSuffix("/")
            ? "\(currentPath)\(name)"
            : "\(currentPath)/\(name)"
        if isDir {
            await list(path: newPath)
        }
    }

    func download(file: FileInfo) async {
        let path = currentPath.hasSuffix("/")
            ? "\(currentPath)\(file.name)"
            : "\(currentPath)/\(file.name)"
        guard let data = try? await api.downloadPodFile(namespace: namespace, podName: podName, container: container, path: path) else { return }
        // Save via UIDocumentPickerViewController – presented via a notification/callback
        NotificationCenter.default.post(name: .podFileDownloadReady, object: (data, file.name))
    }
}

extension Notification.Name {
    static let podFileDownloadReady = Notification.Name("podFileDownloadReady")
}

struct PodFileBrowserView: View {
    let namespace: String
    let podName: String
    let container: String

    @StateObject private var vm: PodFileBrowserViewModel
    @State private var downloadData: Data?
    @State private var downloadName = ""
    @State private var showShareSheet = false

    init(namespace: String, podName: String, container: String) {
        self.namespace = namespace
        self.podName   = podName
        self.container = container
        _vm = StateObject(wrappedValue: PodFileBrowserViewModel(namespace: namespace, podName: podName, container: container))
    }

    var body: some View {
        List {
            if vm.currentPath != "/" {
                Button {
                    let lastCount = (vm.currentPath.split(separator: "/").last?.count ?? 0) + 1
                    let parent = String(vm.currentPath.dropLast(lastCount))
                    Task { await vm.list(path: parent.isEmpty ? "/" : parent) }
                } label: {
                    Label("..", systemImage: "arrow.up.doc")
                }
            }
            ForEach(vm.files) { file in
                HStack {
                    Image(systemName: file.isDir ? "folder.fill" : "doc")
                        .foregroundStyle(file.isDir ? .yellow : .secondary)
                    VStack(alignment: .leading) {
                        Text(file.name).font(.subheadline)
                        if !file.isDir {
                            Text(file.size).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if !file.isDir {
                        Button {
                            Task { await vm.download(file: file) }
                        } label: {
                            Image(systemName: "arrow.down.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if file.isDir {
                        Task { await vm.navigate(to: file.name, isDir: true) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(vm.currentPath)
        .navigationBarTitleDisplayMode(.inline)
        .loadingOverlay(vm.isLoading)
        .task { await vm.list() }
        .onReceive(NotificationCenter.default.publisher(for: .podFileDownloadReady)) { notif in
            if let (data, name) = notif.object as? (Data, String) {
                downloadData = data
                downloadName = name
                showShareSheet = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let data = downloadData {
                ShareSheetView(data: data, filename: downloadName)
            }
        }
    }
}

private struct ShareSheetView: UIViewControllerRepresentable {
    let data: Data
    let filename: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: – Full Pod detail with tabs for Logs / Terminal / Files

struct PodFullDetailView: View {
    let target: ResourceNavTarget
    @State private var pod: Pod?
    @State private var selectedTab = "overview"
    @State private var showLogs = false
    @State private var showTerminal = false
    @State private var showFiles = false

    private var containerNames: [String] {
        pod?.spec?.containers.map { $0.name } ?? []
    }

    var body: some View {
        VStack {
            ResourceDetailView(target: target)

            if let pod {
                HStack(spacing: 12) {
                    Button {
                        showLogs = true
                    } label: {
                        Label("Logs", systemImage: "text.alignleft")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showTerminal = true
                    } label: {
                        Label("Terminal", systemImage: "terminal")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showFiles = true
                    } label: {
                        Label("Files", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        .task {
            pod = try? await APIClient.shared.getResource(
                kind: "pods", namespace: target.namespace, name: target.name
            )
        }
        .sheet(isPresented: $showLogs) {
            NavigationStack {
                PodLogsView(
                    namespace: target.namespace ?? "",
                    podName: target.name,
                    containers: containerNames
                )
            }
        }
        .sheet(isPresented: $showTerminal) {
            NavigationStack {
                PodTerminalView(
                    namespace: target.namespace ?? "",
                    podName: target.name,
                    containers: containerNames
                )
            }
        }
        .sheet(isPresented: $showFiles) {
            NavigationStack {
                PodFileBrowserView(
                    namespace: target.namespace ?? "",
                    podName: target.name,
                    container: containerNames.first ?? ""
                )
            }
        }
    }
}
