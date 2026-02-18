import Foundation

class TitleManager: ObservableObject {
    @Published private(set) var customTitles: [String: String] = [:]
    @Published private(set) var pinnedConversations: Set<String> = []
    
    private let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/KiroChatViewer/titles.json")
    
    private let pinnedURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/KiroChatViewer/pinned.json")
    
    init() {
        load()
    }
    
    func setTitle(_ title: String, for conversationId: String) {
        customTitles[conversationId] = title
        save()
    }
    
    func getTitle(for conversationId: String) -> String? {
        customTitles[conversationId]
    }
    
    func togglePin(for conversationId: String) {
        if pinnedConversations.contains(conversationId) {
            pinnedConversations.remove(conversationId)
        } else {
            pinnedConversations.insert(conversationId)
        }
        savePinned()
    }
    
    func isPinned(_ conversationId: String) -> Bool {
        pinnedConversations.contains(conversationId)
    }
    
    private func load() {
        if FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let titles = try? JSONDecoder().decode([String: String].self, from: data) {
            customTitles = titles
        }
        
        if FileManager.default.fileExists(atPath: pinnedURL.path),
           let data = try? Data(contentsOf: pinnedURL),
           let pinned = try? JSONDecoder().decode(Set<String>.self, from: data) {
            pinnedConversations = pinned
        }
    }
    
    private func save() {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(customTitles) else { return }
        try? data.write(to: fileURL)
    }
    
    private func savePinned() {
        try? FileManager.default.createDirectory(at: pinnedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(pinnedConversations) else { return }
        try? data.write(to: pinnedURL)
    }
}
