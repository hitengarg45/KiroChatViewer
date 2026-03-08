import Foundation

struct Conversation: Identifiable, Hashable, Codable {
    let id: String
    let directory: String
    let createdAt: Date
    let updatedAt: Date
    let history: [[MessageWrapper]]
    
    enum CodingKeys: String, CodingKey {
        case id = "conversation_id"
        case history
    }
    
    init(id: String, directory: String, createdAt: Date, updatedAt: Date, history: [[MessageWrapper]]) {
        self.id = id
        self.directory = directory
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.history = history
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        
        if let arrayFormat = try? container.decode([[MessageWrapper]].self, forKey: .history) {
            history = arrayFormat
        } else if let dictFormat = try? container.decode([MessagePair].self, forKey: .history) {
            history = dictFormat.map { [$0.user, $0.assistant] }
        } else {
            history = []
        }
        
        directory = ""
        createdAt = Date()
        updatedAt = Date()
    }
    
    var messages: [Message] {
        // First pass: collect all tool results by tool_use_id
        var allToolResults: [String: ToolResult] = [:]
        for pair in history {
            for wrapper in pair {
                if let toolResults = wrapper.toolUseResults {
                    for tr in toolResults {
                        allToolResults[tr.toolUseId] = tr
                    }
                }
            }
        }
        
        // Second pass: build messages, attaching results to tool calls
        var result: [Message] = []
        for pair in history {
            for wrapper in pair {
                if wrapper.toolUseResults != nil { continue }
                
                if let prompt = wrapper.prompt {
                    result.append(Message(role: .user, content: prompt))
                } else if let toolUse = wrapper.toolUse {
                    var calls = toolUse.toolCalls
                    for i in calls.indices {
                        calls[i].result = allToolResults[calls[i].id]
                    }
                    result.append(Message(role: .tool, content: toolUse.content, toolCalls: calls))
                } else if let response = wrapper.responseText {
                    result.append(Message(role: .assistant, content: response))
                }
            }
        }
        return result
    }
    
    var title: String {
        messages.first?.content.prefix(60).trimmingCharacters(in: .whitespacesAndNewlines) ?? "Untitled"
    }
    
    static func == (lhs: Conversation, rhs: Conversation) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    
    struct MessagePair: Codable {
        let user: MessageWrapper
        let assistant: MessageWrapper
    }
}

// MARK: - Tool Models

struct ToolCall: Identifiable {
    let id: String
    let name: String
    let args: [String: Any]
    var result: ToolResult?
    
    var argsDescription: String {
        args.map { "\($0.key): \(formatValue($0.value))" }.joined(separator: ", ")
    }
    
    var fullArgsDescription: String {
        args.map { "\($0.key): \(formatFullValue($0.value))" }.joined(separator: "\n")
    }
    
    private func formatValue(_ value: Any) -> String {
        if let s = value as? String {
            return s.count > 80 ? "\"\(s.prefix(80))...\"" : "\"\(s)\""
        } else if let arr = value as? [Any] {
            return "[\(arr.count) items]"
        } else if let dict = value as? [String: Any] {
            return "{\(dict.count) keys}"
        }
        return "\(value)"
    }
    
    private func formatFullValue(_ value: Any) -> String {
        if let s = value as? String { return "\"\(s)\"" }
        else if let arr = value as? [Any] {
            return "[\n  " + arr.map { formatFullValue($0) }.joined(separator: ",\n  ") + "\n]"
        } else if let dict = value as? [String: Any] {
            return "{\n  " + dict.map { "\($0.key): \(formatFullValue($0.value))" }.joined(separator: ",\n  ") + "\n}"
        }
        return "\(value)"
    }
}

struct ToolResult {
    let toolUseId: String
    let status: String
    let content: String
}

struct ToolUseInfo {
    let content: String // assistant's explanatory text
    let toolCalls: [ToolCall]
}

// MARK: - Message Wrapper

struct MessageWrapper: Codable {
    let content: ContentType?
    let response: ResponseContent?
    private let toolUseRaw: ToolUseRaw?
    
    enum CodingKeys: String, CodingKey {
        case content
        case Response
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try? container.decode(ContentType.self, forKey: .content)
        response = try? container.decode(ResponseContent.self, forKey: .Response)
        
        let singleContainer = try decoder.singleValueContainer()
        toolUseRaw = try? singleContainer.decode(ToolUseRaw.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(response, forKey: .Response)
    }
    
    var prompt: String? {
        // Check content.Prompt
        if case .prompt(let p) = content { return p.prompt }
        return nil
    }
    
    var responseText: String? {
        // Direct Response key
        if let r = response { return r.content }
        // Response inside content
        if case .response(let r) = content { return r.content }
        return nil
    }
    
    var toolUse: ToolUseInfo? {
        if let tu = toolUseRaw, !tu.toolUses.isEmpty {
            let calls = tu.toolUses.map { raw in
                ToolCall(id: raw.id, name: raw.name, args: raw.args)
            }
            return ToolUseInfo(content: tu.content, toolCalls: calls)
        }
        return nil
    }
    
    var toolUseResults: [ToolResult]? {
        // From content.ToolUseResults
        if case .toolUseResults(let results) = content {
            return results
        }
        return nil
    }
    
    // MARK: - Content Type
    
    enum ContentType: Codable {
        case prompt(PromptContent)
        case response(ResponseContent)
        case toolUseResults([ToolResult])
        
        enum CodingKeys: String, CodingKey {
            case Prompt
            case Response
            case ToolUseResults
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let prompt = try? container.decode(PromptContent.self, forKey: .Prompt) {
                self = .prompt(prompt)
            } else if let response = try? container.decode(ResponseContent.self, forKey: .Response) {
                self = .response(response)
            } else if let turContainer = try? container.decode(ToolUseResultsContainer.self, forKey: .ToolUseResults) {
                self = .toolUseResults(turContainer.results)
            } else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unknown content type"))
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .prompt(let p): try container.encode(p, forKey: .Prompt)
            case .response(let r): try container.encode(r, forKey: .Response)
            case .toolUseResults: break
            }
        }
    }
    
    struct PromptContent: Codable { let prompt: String }
    struct ResponseContent: Codable { let content: String }
}

// MARK: - Raw Decoding Helpers

private struct ToolUseRaw: Codable {
    let content: String
    let toolUses: [ToolUseEntry]
    
    enum CodingKeys: String, CodingKey {
        case ToolUse
    }
    
    struct Inner: Codable {
        let content: String?
        let tool_uses: [ToolUseEntry]?
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let inner = try container.decode(Inner.self, forKey: .ToolUse)
        content = inner.content ?? ""
        toolUses = inner.tool_uses ?? []
    }
    
    func encode(to encoder: Encoder) throws {}
}

struct ToolUseEntry: Codable {
    let id: String
    let name: String
    let args: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case id, name, args
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = (try? container.decode(String.self, forKey: .name)) ?? "unknown"
        
        // Decode args as raw JSON
        if let rawArgs = try? container.decode([String: JSONValue].self, forKey: .args) {
            var dict: [String: Any] = [:]
            for (k, v) in rawArgs { dict[k] = v.rawValue }
            args = dict
        } else {
            args = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {}
}

private struct ToolUseResultsContainer: Codable {
    let results: [ToolResult]
    
    enum CodingKeys: String, CodingKey {
        case tool_use_results
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawResults = (try? container.decode([RawToolResult].self, forKey: .tool_use_results)) ?? []
        results = rawResults.map { $0.toToolResult() }
    }
    
    func encode(to encoder: Encoder) throws {}
}

private struct RawToolResult: Codable {
    let tool_use_id: String
    let status: String?
    let content: JSONValue?
    
    func toToolResult() -> ToolResult {
        let text: String
        switch content {
        case .array(let items):
            // Extract text from [{Json: {content: [{type: "text", text: "..."}]}}] or [{Text: "..."}]
            var parts: [String] = []
            for item in items {
                if case .object(let dict) = item {
                    if case .object(let jsonContent) = dict["Json"] ?? .null,
                       case .array(let contentItems) = jsonContent["content"] ?? .null {
                        for ci in contentItems {
                            if case .object(let ciDict) = ci,
                               case .string(let t) = ciDict["text"] ?? .null {
                                parts.append(t)
                            }
                        }
                    } else if case .string(let t) = dict["Text"] ?? .null {
                        parts.append(t)
                    }
                }
            }
            text = parts.joined(separator: "\n")
        case .string(let s): text = s
        default: text = ""
        }
        return ToolResult(toolUseId: tool_use_id, status: status ?? "unknown", content: text)
    }
}

// MARK: - JSON Value Helper

enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null
    
    var rawValue: Any {
        switch self {
        case .string(let s): return s
        case .number(let n): return n
        case .bool(let b): return b
        case .object(let d): return d.mapValues { $0.rawValue }
        case .array(let a): return a.map { $0.rawValue }
        case .null: return ""
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { self = .string(s) }
        else if let n = try? container.decode(Double.self) { self = .number(n) }
        else if let b = try? container.decode(Bool.self) { self = .bool(b) }
        else if let o = try? container.decode([String: JSONValue].self) { self = .object(o) }
        else if let a = try? container.decode([JSONValue].self) { self = .array(a) }
        else { self = .null }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Message

struct Message: Identifiable, Hashable {
    let id = UUID()
    let role: Role
    let content: String
    let toolCalls: [ToolCall]
    
    init(role: Role, content: String, toolCalls: [ToolCall] = []) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
    }
    
    enum Role {
        case user
        case assistant
        case tool
    }
    
    static func == (lhs: Message, rhs: Message) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
