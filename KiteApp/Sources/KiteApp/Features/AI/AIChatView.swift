import SwiftUI

// MARK: – AI View Model

@MainActor
final class AIViewModel: ObservableObject {
    @Published var sessions: [AISession] = []
    @Published var currentSession: AISession?
    @Published var inputText = ""
    @Published var isSending = false
    @Published var isAIEnabled = false
    @Published var error: String?
    @Published var awaitingInput = false       // backend waiting for user input
    @Published var pendingExecuteApproval = false  // backend waiting for execute approval

    private let api = APIClient.shared

    func checkStatus() async {
        let status = try? await api.aiStatus()
        isAIEnabled = status?.enabled ?? false
    }

    func loadSessions() async {
        sessions = (try? await api.listAISessions()) ?? []
    }

    func selectSession(_ session: AISession) async {
        currentSession = try? await api.getAISession(id: session.id)
    }

    func newSession() async {
        let id = UUID().uuidString
        let session = AISession(id: id, title: nil, messages: [], createdAt: isoNow(), updatedAt: isoNow())
        currentSession = session
    }

    func deleteSession(_ session: AISession) async {
        try? await api.deleteAISession(id: session.id)
        sessions.removeAll { $0.id == session.id }
        if currentSession?.id == session.id { currentSession = nil }
    }

    func send() async {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let msg = inputText
        inputText = ""
        isSending = true
        defer { isSending = false }

        do {
            let req = AIChatRequest(sessionId: currentSession?.id, message: msg)
            let response = try await api.aiChat(req)
            if currentSession == nil || currentSession?.id != response.sessionId {
                currentSession = try await api.getAISession(id: response.sessionId)
            } else {
                currentSession = try await api.getAISession(id: response.sessionId)
            }
            await loadSessions()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func approveExecute() async {
        guard let sessionId = currentSession?.id else { return }
        pendingExecuteApproval = false
        isSending = true
        defer { isSending = false }
        do {
            _ = try await api.aiExecuteContinue(ExecuteContinueRequest(sessionId: sessionId, approved: true))
            currentSession = try await api.getAISession(id: sessionId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func sendInput(_ input: String) async {
        guard let sessionId = currentSession?.id else { return }
        awaitingInput = false
        isSending = true
        defer { isSending = false }
        do {
            _ = try await api.aiInputContinue(InputContinueRequest(sessionId: sessionId, input: input))
            currentSession = try await api.getAISession(id: sessionId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func isoNow() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

// MARK: – AI Chat View

struct AIChatView: View {
    @StateObject private var vm = AIViewModel()
    @State private var showSessions = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if !vm.isAIEnabled {
                    ContentUnavailableView(
                        "AI Not Enabled",
                        systemImage: "sparkles.slash",
                        description: Text("Configure an AI provider in Settings → General to enable the AI assistant.")
                    )
                } else if let session = vm.currentSession {
                    ChatSessionView(vm: vm, session: session)
                } else {
                    ContentUnavailableView(
                        "Start a Conversation",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Tap + to start a new AI session.")
                    )
                }
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await vm.newSession() } } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSessions = true } label: {
                        Image(systemName: "clock")
                    }
                }
            }
        }
        .sheet(isPresented: $showSessions) {
            AISessionListView(vm: vm)
        }
        .task {
            await vm.checkStatus()
            await vm.loadSessions()
        }
    }
}

// MARK: – Session list

struct AISessionListView: View {
    @ObservedObject var vm: AIViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if vm.sessions.isEmpty {
                    Text("No sessions yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(vm.sessions) { session in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(session.title ?? "Session \(session.id.prefix(8))")
                                    .font(.subheadline)
                                Text(session.updatedAt.relativeTimeAgo)
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if vm.currentSession?.id == session.id {
                                Image(systemName: "checkmark").foregroundStyle(.accent)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task {
                                await vm.selectSession(session)
                                dismiss()
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await vm.deleteSession(session) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: – Chat session view

private struct ChatSessionView: View {
    @ObservedObject var vm: AIViewModel
    let session: AISession
    @FocusState private var focused: Bool
    @State private var inputOverride = ""
    @State private var showInputPrompt = false

    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(session.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                        if vm.isSending {
                            HStack {
                                ProgressView()
                                Text("Thinking…").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding()
                }
                .onChange(of: session.messages.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
            }

            Divider()

            // Execute approval
            if vm.pendingExecuteApproval {
                HStack {
                    Text("AI wants to execute a command. Approve?")
                        .font(.footnote)
                    Spacer()
                    Button("Approve") { Task { await vm.approveExecute() } }
                        .buttonStyle(.borderedProminent)
                    Button("Deny", role: .destructive) {
                        vm.pendingExecuteApproval = false
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.yellow.opacity(0.1))
            }

            // Input field
            HStack(spacing: 10) {
                TextField("Message…", text: $vm.inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .focused($focused)
                    .onSubmit { Task { await vm.send() } }

                Button {
                    Task { await vm.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(vm.inputText.isEmpty ? .secondary : .accent)
                }
                .disabled(vm.inputText.isEmpty || vm.isSending)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

// MARK: – Chat bubble

private struct ChatBubble: View {
    let message: AIMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role != .user {
                    Label("Kite AI", systemImage: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(message.content)
                    .padding(10)
                    .background(message.role == .user ? Color.accentColor : Color.secondary.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .textSelection(.enabled)

                // Tool calls
                if let tools = message.toolCalls, !tools.isEmpty {
                    ForEach(tools) { tool in
                        ToolCallRow(tool: tool)
                    }
                }

                Text(message.createdAt.relativeTimeAgo)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if message.role != .user { Spacer(minLength: 40) }
        }
    }
}

private struct ToolCallRow: View {
    let tool: ToolCall

    private var statusColor: Color {
        switch tool.status {
        case .done:    return .k8sGreen
        case .error:   return .k8sRed
        case .running: return .k8sYellow
        default:       return .k8sGray
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "terminal")
                .font(.caption)
                .foregroundStyle(statusColor)
            Text(tool.function?.name ?? "tool")
                .font(.caption.monospaced())
            if let status = tool.status {
                Text(status.rawValue)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(6)
        .background(statusColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}
