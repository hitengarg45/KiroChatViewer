import Foundation

// MARK: - JSON-RPC

struct ACPRequest: Encodable {
    let jsonrpc = "2.0"
    let id: Int
    let method: String
    let params: [String: AnyCodable]
}

struct ACPNotification: Decodable {
    let jsonrpc: String
    let method: String?
    let params: SessionUpdateParams?
    let result: AnyCodable?
    let id: Int?
    let error: ACPError?
}

struct ACPError: Decodable {
    let code: Int
    let message: String
}

// MARK: - Initialize

struct InitResult: Decodable {
    let protocolVersion: AnyCodable?
    let agentInfo: AgentInfo?
    let agentCapabilities: AnyCodable?
}

struct AgentInfo: Decodable {
    let name: String
    let title: String?
    let version: String?
}

// MARK: - Session

struct SessionNewResult: Decodable {
    let sessionId: String
    let modes: SessionModes?
    let tools: [ToolInfo]?
    let mcpServers: [MCPServerInfo]?
    let commands: [CommandInfo]?
}

struct SessionModes: Decodable {
    let currentModeId: String?
    let availableModes: [ModeInfo]?
}

struct ModeInfo: Decodable, Identifiable {
    let id: String
    let name: String
    let description: String?
}

struct ToolInfo: Decodable, Identifiable {
    let name: String
    let description: String?
    let source: String?
    var id: String { name }
}

struct MCPServerInfo: Decodable, Identifiable {
    let name: String
    let status: String?
    let toolCount: Int?
    var id: String { name }
}

struct CommandInfo: Decodable, Identifiable {
    let name: String
    let description: String?
    var id: String { name }
}

// MARK: - Session Update

struct SessionUpdateParams: Decodable {
    let sessionId: String?
    let update: SessionUpdate?
    // For commands/available notification
    let commands: [CommandInfo]?
}

struct SessionUpdate: Decodable {
    let kind: String
    let content: MessageContent?
    let name: String?
    let status: String?
    let toolCallId: String?
    let parameters: AnyCodable?
    let stopReason: String?
}

struct MessageContent: Decodable {
    let type: String?
    let text: String?
}

// MARK: - AnyCodable helper

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) { self.value = value }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { value = s }
        else if let i = try? container.decode(Int.self) { value = i }
        else if let d = try? container.decode(Double.self) { value = d }
        else if let b = try? container.decode(Bool.self) { value = b }
        else if let a = try? container.decode([AnyCodable].self) { value = a.map { $0.value } }
        else if let o = try? container.decode([String: AnyCodable].self) { value = o.mapValues { $0.value } }
        else { value = "" }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let s = value as? String { try container.encode(s) }
        else if let i = value as? Int { try container.encode(i) }
        else if let d = value as? Double { try container.encode(d) }
        else if let b = value as? Bool { try container.encode(b) }
        else if let a = value as? [Any] { try container.encode(a.map { AnyCodable($0) }) }
        else if let o = value as? [String: Any] { try container.encode(o.mapValues { AnyCodable($0) }) }
        else { try container.encodeNil() }
    }
}
