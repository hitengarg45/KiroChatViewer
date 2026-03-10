import Foundation

// MARK: - Database Protocol

protocol DatabaseProviding: ObservableObject {
    var conversations: [Conversation] { get }
    func loadConversations()
    func deleteConversation(_ conversation: Conversation)
}

// MARK: - Backup Protocol

protocol BackupProviding: ObservableObject {
    var backups: [URL] { get }
    func createBackup() -> URL?
    func mergeFromBackup(_ url: URL) -> Bool
}

// MARK: - Title Protocol

protocol TitleProviding: ObservableObject {
    func getTitle(for id: String) -> String?
    func setTitle(_ title: String, for id: String)
    func isPinned(_ id: String) -> Bool
    func togglePin(for id: String)
}

// MARK: - ACP Protocol

protocol ACPProviding: ObservableObject {
    var state: ACPState { get }
    var sessionId: String? { get }
    func connect(cwd: String)
    func prompt(text: String)
    func cancel()
    func disconnect()
}
