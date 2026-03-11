import Foundation

struct BookmarkFolder: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var conversationIds: [String]
    var isBuiltIn: Bool
    
    static let starred = BookmarkFolder(id: "starred", name: "Starred", conversationIds: [], isBuiltIn: true)
}

struct BookmarkData: Codable {
    var folders: [BookmarkFolder]
}

class BookmarkManager: ObservableObject {
    @Published var folders: [BookmarkFolder] = [.starred]
    
    private let fileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/KiroChatViewer")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("bookmarks.json")
    }()
    
    init() {
        Task.detached(priority: .utility) { [self] in
            let loaded = Self.loadFromDisk(fileURL: self.fileURL)
            await MainActor.run {
                self.folders = loaded
            }
        }
    }
    
    private static func loadFromDisk(fileURL: URL) -> [BookmarkFolder] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(BookmarkData.self, from: data) else {
            return [.starred]
        }
        var folders = decoded.folders
        if !folders.contains(where: { $0.id == "starred" }) {
            folders.insert(.starred, at: 0)
        }
        return folders
    }
    
    private func save() {
        let data = try? JSONEncoder().encode(BookmarkData(folders: folders))
        try? data?.write(to: fileURL)
    }
    
    func createFolder(name: String) {
        let folder = BookmarkFolder(id: UUID().uuidString, name: name, conversationIds: [], isBuiltIn: false)
        folders.append(folder)
        save()
    }
    
    func deleteFolder(_ folder: BookmarkFolder) {
        guard !folder.isBuiltIn else { return }
        folders.removeAll { $0.id == folder.id }
        save()
    }
    
    func renameFolder(_ folder: BookmarkFolder, to name: String) {
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[idx].name = name
        save()
    }
    
    func addBookmark(conversationId: String, to folderId: String) {
        guard let idx = folders.firstIndex(where: { $0.id == folderId }) else { return }
        if !folders[idx].conversationIds.contains(conversationId) {
            folders[idx].conversationIds.append(conversationId)
            save()
        }
    }
    
    func removeBookmark(conversationId: String, from folderId: String) {
        guard let idx = folders.firstIndex(where: { $0.id == folderId }) else { return }
        folders[idx].conversationIds.removeAll { $0 == conversationId }
        save()
    }
    
    func foldersContaining(conversationId: String) -> [BookmarkFolder] {
        folders.filter { $0.conversationIds.contains(conversationId) }
    }
    
    func isBookmarked(conversationId: String) -> Bool {
        folders.contains { $0.conversationIds.contains(conversationId) }
    }
}
