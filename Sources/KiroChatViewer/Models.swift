import Foundation

struct Conversation: Identifiable, Codable, Hashable {
    let id: String
    let directory: String
    let createdAt: Date
    let updatedAt: Date
    let history: [Message]
    
    var title: String {
        history.first?.content.prefix(60).trimmingCharacters(in: .whitespacesAndNewlines) ?? "Untitled"
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
        history = try container.decode([Message].self, forKey: .history)
        directory = ""
        createdAt = Date()
        updatedAt = Date()
    }
    
    init(id: String, directory: String, createdAt: Date, updatedAt: Date, history: [Message]) {
        self.id = id
        self.directory = directory
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.history = history
    }
}

struct Message: Identifiable, Hashable {
    let id = UUID()
    let role: Role
    let content: String
    
    enum Role: String {
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

extension Message: Codable {
    enum CodingKeys: String, CodingKey {
        case user
        case assistant
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let userContent = try? container.decode(MessageContent.self, forKey: .user) {
            role = .user
            content = userContent.text
        } else if let assistantContent = try? container.decode(MessageContent.self, forKey: .assistant) {
            role = .assistant
            content = assistantContent.text
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid message"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let content = MessageContent(text: self.content)
        switch role {
        case .user:
            try container.encode(content, forKey: .user)
        case .assistant:
            try container.encode(content, forKey: .assistant)
        }
    }
    
    struct MessageContent: Codable {
        let text: String
        
        enum CodingKeys: String, CodingKey {
            case text = "content"
        }
        
        init(text: String) {
            self.text = text
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let textValue = try? container.decode(String.self, forKey: .text) {
                text = textValue
            } else if let arrayValue = try? container.decode([ContentBlock].self, forKey: .text) {
                text = arrayValue.compactMap { $0.text }.joined(separator: "\n")
            } else {
                text = ""
            }
        }
    }
    
    struct ContentBlock: Codable {
        let text: String?
    }
}
