import Foundation

struct Conversation: Identifiable, Codable, Hashable {
    let id: String
    let directory: String
    let createdAt: Date
    let updatedAt: Date
    let history: [[MessageWrapper]]
    
    var messages: [Message] {
        history.flatMap { pair in
            pair.compactMap { wrapper in
                if let prompt = wrapper.prompt {
                    return Message(role: .user, content: prompt)
                } else if let response = wrapper.responseText {
                    return Message(role: .assistant, content: response)
                }
                return nil
            }
        }
    }
    
    var title: String {
        messages.first?.content.prefix(60).trimmingCharacters(in: .whitespacesAndNewlines) ?? "Untitled"
    }
    
    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "conversation_id"
        case history
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        
        // Try to decode as array of arrays first (new format)
        if let arrayFormat = try? container.decode([[MessageWrapper]].self, forKey: .history) {
            history = arrayFormat
        }
        // Fall back to dictionary format (old format)
        else if let dictFormat = try? container.decode([MessagePair].self, forKey: .history) {
            history = dictFormat.map { [$0.user, $0.assistant] }
        }
        else {
            history = []
        }
        
        directory = ""
        createdAt = Date()
        updatedAt = Date()
    }
    
    struct MessagePair: Codable {
        let user: MessageWrapper
        let assistant: MessageWrapper
    }
    
    init(id: String, directory: String, createdAt: Date, updatedAt: Date, history: [[MessageWrapper]]) {
        self.id = id
        self.directory = directory
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.history = history
    }
}

struct MessageWrapper: Codable {
    let content: ContentType?
    let response: ResponseContent?
    
    enum CodingKeys: String, CodingKey {
        case content
        case Response
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try? container.decode(ContentType.self, forKey: .content)
        response = try? container.decode(ResponseContent.self, forKey: .Response)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(response, forKey: .Response)
    }
    
    var prompt: String? {
        if case .prompt(let p) = content {
            return p.prompt
        }
        return nil
    }
    
    var responseText: String? {
        return response?.content
    }
    
    enum ContentType: Codable {
        case prompt(PromptContent)
        case response(ResponseContent)
        
        enum CodingKeys: String, CodingKey {
            case Prompt
            case Response
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let prompt = try? container.decode(PromptContent.self, forKey: .Prompt) {
                self = .prompt(prompt)
            } else if let response = try? container.decode(ResponseContent.self, forKey: .Response) {
                self = .response(response)
            } else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unknown content type"))
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .prompt(let p):
                try container.encode(p, forKey: .Prompt)
            case .response(let r):
                try container.encode(r, forKey: .Response)
            }
        }
    }
    
    struct PromptContent: Codable {
        let prompt: String
    }
    
    struct ResponseContent: Codable {
        let content: String
    }
}

struct Message: Identifiable, Hashable {
    let id = UUID()
    let role: Role
    let content: String
    
    enum Role {
        case user
        case assistant
    }
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
