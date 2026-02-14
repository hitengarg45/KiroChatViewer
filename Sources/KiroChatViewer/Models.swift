import Foundation

struct Conversation: Identifiable, Codable {
    let id: String
    let directory: String
    let createdAt: Date
    let updatedAt: Date
    let history: [Message]
    
    var title: String {
        history.first?.content.prefix(60).trimmingCharacters(in: .whitespacesAndNewlines) ?? "Untitled"
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

struct Message: Codable, Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    
    enum Role: String, Codable {
        case user
        case assistant
    }
    
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
    
    struct MessageContent: Codable {
        let text: String
        
        enum CodingKeys: String, CodingKey {
            case text = "content"
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
