import Foundation
import SQLite

class DatabaseManager: ObservableObject, DatabaseProviding {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let dbPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/kiro-cli/data.sqlite3")
    
    func loadConversations() {
        isLoading = true
        error = nil
        
        Task.detached(priority: .userInitiated) { [dbPath] in
            let start = Date()
            AppLogger.db.info("Loading conversations from: \(dbPath.path)")
            
            do {
                // Single query, single connection — all on background thread
                var allConvs = try Self.fetchConversations(from: dbPath)
                AppLogger.perf.info("Loaded \(allConvs.count) conversations in \(Date().timeIntervalSince(start) * 1000, privacy: .public)ms")
                
                // Merge from latest backup — background thread
                if let backupURL = BackupManager.shared.latestBackupURL, backupURL.path != dbPath.path {
                    let backupConvs = (try? Self.fetchConversations(from: backupURL)) ?? []
                    let existingIds = Set(allConvs.map { $0.id })
                    let onlyInBackup = backupConvs.filter { !existingIds.contains($0.id) }
                    AppLogger.db.info("Backup contributed \(onlyInBackup.count) additional conversations")
                    allConvs += onlyInBackup
                }
                
                // Deduplicate + sort — background thread
                var seen = Set<String>()
                let unique = allConvs.filter { conv in
                    if seen.contains(conv.id) { return false }
                    seen.insert(conv.id)
                    return true
                }
                let sorted = unique.sorted { $0.updatedAt > $1.updatedAt }
                AppLogger.db.info("Total unique conversations: \(sorted.count)")
                
                // Single publish on main thread
                await MainActor.run {
                    self.conversations = sorted
                    self.isLoading = false
                }
            } catch {
                AppLogger.db.error("Failed to load conversations: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Fetch all conversations from a SQLite DB — runs on caller's thread (must be background)
    private static func fetchConversations(from url: URL) throws -> [Conversation] {
        let db = try Connection(url.path)
        let table = Table("conversations_v2")
        let key = Expression<String>("key")
        let conversationId = Expression<String>("conversation_id")
        let value = Expression<String>("value")
        let createdAt = Expression<Int64>("created_at")
        let updatedAt = Expression<Int64>("updated_at")
        
        let appSupportPath = NSHomeDirectory() + "/Library/Application Support"
        var result: [Conversation] = []
        
        for row in try db.prepare(table.order(updatedAt.desc)) {
            let directory = row[key]
            if directory.hasPrefix(appSupportPath) { continue }
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
    
    func reloadConversation(id: String) async -> Conversation? {
        let dbPath = self.dbPath
        return await Task.detached(priority: .userInitiated) {
            do {
                let db = try Connection(dbPath.path)
                let table = Table("conversations_v2")
                let key = Expression<String>("key")
                let conversationId = Expression<String>("conversation_id")
                let value = Expression<String>("value")
                let createdAt = Expression<Int64>("created_at")
                let updatedAt = Expression<Int64>("updated_at")
                
                let query = table.filter(conversationId == id)
                for row in try db.prepare(query) {
                    guard let data = row[value].data(using: .utf8) else { continue }
                    var conv = try JSONDecoder().decode(Conversation.self, from: data)
                    conv = Conversation(
                        id: conv.id,
                        directory: row[key],
                        createdAt: Date(timeIntervalSince1970: Double(row[createdAt]) / 1000),
                        updatedAt: Date(timeIntervalSince1970: Double(row[updatedAt]) / 1000),
                        history: conv.history
                    )
                    return conv
                }
            } catch {
                AppLogger.db.error("Failed to reload conversation \(id): \(error.localizedDescription)")
            }
            return nil
        }.value
    }
    
    func deleteConversation(_ conversation: Conversation) {
        // Remove from UI immediately
        conversations.removeAll { $0.id == conversation.id }
        // Delete from DB on background
        let dbPath = self.dbPath
        let convId = conversation.id
        Task.detached(priority: .utility) {
            do {
                let db = try Connection(dbPath.path)
                let table = Table("conversations_v2")
                let conversationId = Expression<String>("conversation_id")
                try db.run(table.filter(conversationId == convId).delete())
            } catch {
                AppLogger.db.error("Delete failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = "Delete failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
