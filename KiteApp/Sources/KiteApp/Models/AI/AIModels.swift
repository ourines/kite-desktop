import Foundation

// MARK: – AI session

struct AISession: Codable, Identifiable {
    var id: String
    var title: String?
    var messages: [AIMessage]
    var createdAt: String
    var updatedAt: String
}

struct AIMessage: Codable, Identifiable {
    var id: String
    var role: MessageRole
    var content: String
    var toolCalls: [ToolCall]?
    var createdAt: String

    enum MessageRole: String, Codable {
        case user, assistant, system, tool
    }
}

struct ToolCall: Codable, Identifiable {
    var id: String
    var type: String
    var function: FunctionCall?
    var status: ToolCallStatus?
    var result: String?

    enum ToolCallStatus: String, Codable {
        case pending, running, done, error
    }
}

struct FunctionCall: Codable {
    var name: String
    var arguments: String
}

// MARK: – Chat request / response

struct AIChatRequest: Codable {
    var sessionId: String?
    var message: String
}

struct AIChatResponse: Codable {
    var sessionId: String
    var message: AIMessage
    var done: Bool
}

// MARK: – AI status

struct AIStatus: Codable {
    var enabled: Bool
}

// MARK: – Execute continue

struct ExecuteContinueRequest: Codable {
    var sessionId: String
    var approved: Bool
}

struct InputContinueRequest: Codable {
    var sessionId: String
    var input: String
}
