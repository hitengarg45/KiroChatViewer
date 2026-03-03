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
            await _loadConversations()
        }
    }
    
    @MainActor
    func _loadConversations() async {
        isLoading = true
        error = nil
        AppLogger.db.info("Loading conversations from: \(self.dbPath.path)")
        do {
            let start = Date()
            let firstBatch = try await fetchConversations(from: dbPath, limit: 50, offset: 0)
            AppLogger.perf.info("First batch loaded: \(firstBatch.count) conversations in \(Date().timeIntervalSince(start) * 1000, privacy: .public)ms")
            self.conversations = firstBatch.sorted { $0.updatedAt > $1.updatedAt }
            
            let remaining = try await fetchConversations(from: dbPath, limit: nil, offset: 50)
            AppLogger.db.info("Background load complete: \(remaining.count) additional conversations")
            var allConvs = firstBatch + remaining
            
            // Merge from latest backup — kiro-cli wins on duplicates
            if let backupURL = BackupManager.shared.latestBackupURL, backupURL.path != dbPath.path {
                let backupConvs = (try? await fetchConversations(from: backupURL)) ?? []
                let existingIds = Set(allConvs.map { $0.id })
                let onlyInBackup = backupConvs.filter { !existingIds.contains($0.id) }
                AppLogger.db.info("Backup contributed \(onlyInBackup.count) additional conversations")
                allConvs += onlyInBackup
            }
            
            // Remove duplicates by ID
            var seen = Set<String>()
            let unique = allConvs.filter { conv in
                if seen.contains(conv.id) { return false }
                seen.insert(conv.id)
                return true
            }
            
            AppLogger.db.info("Total unique conversations: \(unique.count)")
            self.conversations = unique.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            AppLogger.db.error("Failed to load conversations: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
        self.isLoading = false
    }
    
    private func fetchConversations(from url: URL, limit: Int? = nil, offset: Int = 0) async throws -> [Conversation] {
        let db = try Connection(url.path)
        let table = Table("conversations_v2")
        let key = Expression<String>("key")
        let conversationId = Expression<String>("conversation_id")
        let value = Expression<String>("value")
        let createdAt = Expression<Int64>("created_at")
        let updatedAt = Expression<Int64>("updated_at")
        
        let kiroCliPath = NSHomeDirectory() + "/Library/Application Support/kiro-cli"
        
        var result: [Conversation] = []
        
        var query = table.order(updatedAt.desc)
        if let limit = limit {
            query = query.limit(limit, offset: offset)
        }
        
        for row in try db.prepare(query) {
            let directory = row[key]
            
            // Skip conversations in kiro-cli's own directories
            if directory.hasPrefix(kiroCliPath) {
                continue
            }
            
            guard let data = row[value].data(using: .utf8) else { continue }
            
            do {
                var conv = try JSONDecoder().decode(Conversation.self, from: data)
                conv = Conversation(
                    id: conv.id,
                    directory: directory,
                    createdAt: Date(timeIntervalSince1970: Double(row[createdAt]) / 1000),
                    updatedAt: Date(timeIntervalSince1970: Double(row[updatedAt]) / 1000),
                    history: conv.history
                )
                result.append(conv)
            } catch {
                AppLogger.db.error("Failed to decode conversation \(row[conversationId]): \(error.localizedDescription)")
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
