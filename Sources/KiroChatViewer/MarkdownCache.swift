import SwiftUI

class MarkdownCache: ObservableObject {
    private var cache: [String: String] = [:]
    
    func get(_ key: String, content: String) -> String {
        if let cached = cache[key] { return cached }
        cache[key] = content
        return content
    }
    
    func clear() { cache.removeAll() }
}
