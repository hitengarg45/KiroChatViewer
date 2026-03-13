import Foundation

// MARK: - ACP Session Metadata

struct ACPSession: Identifiable, Hashable {
    let id: String
    let cwd: String
    let createdAt: Date
    let updatedAt: Date
    let turnCount: Int
    let firstPrompt: String
    
    static func == (lhs: ACPSession, rhs: ACPSession) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    
    var title: String {
        firstPrompt.isEmpty ? "Untitled" : String(firstPrompt.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var directoryName: String {
        cwd.split(separator: "/").last.map(String.init) ?? cwd
    }
}

// MARK: - ACP Session Event

struct ACPSessionEvent {
    let kind: String // "Prompt", "AssistantMessage", "ToolResults"
    let content: String
    let messageId: String
}

// MARK: - ACP Session Manager

class ACPSessionManager: ObservableObject {
    @Published var sessions: [ACPSession] = []
    @Published var isLoading = false
    
    private let sessionsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".kiro/sessions/cli")
    
    func loadSessions() {
        isLoading = true
        Task.detached(priority: .userInitiated) { [sessionsDir] in
            let loaded = Self.fetchSessions(from: sessionsDir)
            AppLogger.db.info("Loaded \(loaded.count) ACP sessions")
            await MainActor.run {
                self.sessions = loaded
                self.isLoading = false
            }
        }
    }
    
    private static func fetchSessions(from dir: URL) -> [ACPSession] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        
        let jsonFiles = files.filter { $0.pathExtension == "json" }
        var results: [ACPSession] = []
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        for file in jsonFiles {
            guard let data = try? Data(contentsOf: file),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            
            let sessionId = json["session_id"] as? String ?? file.deletingPathExtension().lastPathComponent
            let cwd = json["cwd"] as? String ?? ""
            let createdStr = json["created_at"] as? String ?? ""
            let updatedStr = json["updated_at"] as? String ?? ""
            let createdAt = dateFormatter.date(from: createdStr) ?? .distantPast
            let updatedAt = dateFormatter.date(from: updatedStr) ?? .distantPast
            
            // Count turns from metadata
            let state = json["session_state"] as? [String: Any] ?? [:]
            let meta = state["conversation_metadata"] as? [String: Any] ?? [:]
            let turns = meta["user_turn_metadatas"] as? [[String: Any]] ?? []
            
            // Get first prompt from .jsonl
            let jsonlFile = file.deletingPathExtension().appendingPathExtension("jsonl")
            let firstPrompt = Self.firstPrompt(from: jsonlFile)
            
            results.append(ACPSession(
                id: sessionId, cwd: cwd, createdAt: createdAt, updatedAt: updatedAt,
                turnCount: turns.count, firstPrompt: firstPrompt
            ))
        }
        
        return results.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    private static func firstPrompt(from jsonlURL: URL) -> String {
        guard let data = try? String(contentsOf: jsonlURL, encoding: .utf8) else { return "" }
        for line in data.components(separatedBy: "\n") {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  json["kind"] as? String == "Prompt",
                  let eventData = json["data"] as? [String: Any],
                  let content = eventData["content"] as? [[String: Any]],
                  let first = content.first,
                  let text = first["data"] as? String else { continue }
            return text
        }
        return ""
    }
    
    func loadEvents(for sessionId: String) -> [ACPSessionEvent] {
        let jsonlFile = sessionsDir.appendingPathComponent("\(sessionId).jsonl")
        guard let data = try? String(contentsOf: jsonlFile, encoding: .utf8) else { return [] }
        
        var events: [ACPSessionEvent] = []
        for line in data.components(separatedBy: "\n") {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let kind = json["kind"] as? String,
                  let eventData = json["data"] as? [String: Any] else { continue }
            
            let messageId = eventData["message_id"] as? String ?? ""
            var text = ""
            if let content = eventData["content"] as? [[String: Any]] {
                for block in content {
                    if let blockKind = block["kind"] as? String {
                        if blockKind == "text", let t = block["data"] as? String {
                            text += t
                        } else if blockKind == "toolResult",
                                  let trData = block["data"] as? [String: Any],
                                  let toolName = trData["tool_name"] as? String {
                            text += "🔧 \(toolName)"
                        }
                    }
                }
            }
            events.append(ACPSessionEvent(kind: kind, content: text, messageId: messageId))
        }
        return events
    }
}
