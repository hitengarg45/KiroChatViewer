import Foundation
import SQLite

class DatabaseManager: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let dbPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/kiro-cli/data.sqlite3")
    
    func loadConversations() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let convs = try await fetchConversations()
                await MainActor.run {
                    self.conversations = convs.sorted { $0.updatedAt > $1.updatedAt }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func fetchConversations() async throws -> [Conversation] {
        let db = try Connection(dbPath.path)
        let table = Table("conversations_v2")
        let key = Expression<String>("key")
        let conversationId = Expression<String>("conversation_id")
        let value = Expression<String>("value")
        let createdAt = Expression<Int64>("created_at")
        let updatedAt = Expression<Int64>("updated_at")
        
        var result: [Conversation] = []
        
        for row in try db.prepare(table) {
            guard let data = row[value].data(using: .utf8) else { continue }
            
            do {
                var conv = try JSONDecoder().decode(Conversation.self, from: data)
                conv = Conversation(
                    id: conv.id,
                    directory: row[key],
                    createdAt: Date(timeIntervalSince1970: Double(row[createdAt]) / 1000),
                    updatedAt: Date(timeIntervalSince1970: Double(row[updatedAt]) / 1000),
                    history: conv.history
                )
                result.append(conv)
            } catch {
                print("Failed to decode conversation \(row[conversationId]): \(error)")
            }
        }
        
        return result
    }
    
    func deleteConversation(_ conversation: Conversation) {
        do {
            let db = try Connection(dbPath.path)
            let table = Table("conversations_v2")
            let conversationId = Expression<String>("conversation_id")
            try db.run(table.filter(conversationId == conversation.id).delete())
            conversations.removeAll { $0.id == conversation.id }
        } catch {
            self.error = "Delete failed: \(error.localizedDescription)"
        }
    }
}
