import Foundation

class TitleManager: ObservableObject {
    @Published private(set) var customTitles: [String: String] = [:]
    
    private let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/KiroChatViewer/titles.json")
    
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
    
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let titles = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        customTitles = titles
    }
    
    private func save() {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(customTitles) else { return }
        try? data.write(to: fileURL)
    }
}
