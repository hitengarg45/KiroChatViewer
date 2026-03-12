import SwiftUI

class PerformanceMonitor: ObservableObject {
    @Published var metrics: [String: String] = [:]
    private var timers: [String: Date] = [:]
    
    func start(_ key: String) {
        timers[key] = Date()
    }
    
    func end(_ key: String) {
        guard let start = timers[key] else { return }
        let duration = Date().timeIntervalSince(start)
        metrics[key] = String(format: "%.0fms", duration * 1000)
        timers.removeValue(forKey: key)
    }
    
    func record(_ key: String, _ value: String) {
        metrics[key] = value
    }
    
    /// Snapshot current app-wide stats from live data
    func captureAppMetrics(
        conversations: [Conversation],
        titles: TitleManager,
        bookmarks: BookmarkManager
    ) {
        let convCount = conversations.count
        record("Conversations", "\(convCount)")
        
        let totalMessages = conversations.reduce(0) { $0 + $1.messageCount }
        record("Total Messages", "\(totalMessages)")
        
        let avgMessages = convCount > 0 ? totalMessages / convCount : 0
        record("Avg Msgs/Conv", "\(avgMessages)")
        
        let largestConv = conversations.max(by: { $0.messageCount < $1.messageCount })
        if let largest = largestConv {
            record("Largest Conv", "\(largest.messageCount) msgs")
        }
        
        // Titles
        let titledCount = conversations.filter { titles.hasTitle(for: $0.id) }.count
        record("Titled", "\(titledCount)/\(convCount)")
        record("Pinned", "\(titles.pinnedConversations.count)")
        
        // Bookmarks
        let bookmarked = conversations.filter { bookmarks.isBookmarked(conversationId: $0.id) }.count
        record("Bookmarked", "\(bookmarked)")
        
        // Memory estimate: rough size of cached message data
        let jsonBytes = conversations.reduce(0) { total, conv in
            total + conv.history.count * 200 // rough estimate per wrapper
        }
        record("Est. Data Size", ByteCountFormatter.string(fromByteCount: Int64(jsonBytes), countStyle: .memory))
        
        // DB file size
        let dbPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/kiro-cli/data.sqlite3")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath.path),
           let size = attrs[.size] as? Int64 {
            record("DB Size", ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
        }
        
        // Workspaces
        let workspaces = Set(conversations.map { $0.directory }).count
        record("Workspaces", "\(workspaces)")
    }
}

// MARK: - Performance Popover

struct PerformancePopover: View {
    @ObservedObject var monitor: PerformanceMonitor
    
    private var sections: [(title: String, items: [(String, String)])] {
        let all = monitor.metrics
        
        let timing = ["Load"].compactMap { k in all[k].map { (k, $0) } }
        
        let data: [(String, String)] = [
            "Conversations", "Total Messages", "Avg Msgs/Conv",
            "Largest Conv", "Workspaces"
        ].compactMap { k in all[k].map { (k, $0) } }
        
        let state: [(String, String)] = [
            "Titled", "Pinned", "Bookmarked"
        ].compactMap { k in all[k].map { (k, $0) } }
        
        let storage: [(String, String)] = [
            "DB Size", "Est. Data Size"
        ].compactMap { k in all[k].map { (k, $0) } }
        
        // Anything not in the above categories
        let known = Set(["Load", "Conversations", "Total Messages", "Avg Msgs/Conv",
                         "Largest Conv", "Workspaces", "Titled", "Pinned",
                         "Bookmarked", "DB Size", "Est. Data Size", "Count"])
        let other = all.filter { !known.contains($0.key) }
            .sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
        
        var result: [(String, [(String, String)])] = []
        if !timing.isEmpty { result.append(("⏱ Timing", timing)) }
        if !data.isEmpty { result.append(("📊 Data", data)) }
        if !state.isEmpty { result.append(("📌 State", state)) }
        if !storage.isEmpty { result.append(("💾 Storage", storage)) }
        if !other.isEmpty { result.append(("🔧 Other", other)) }
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Performance Metrics")
                    .font(.headline)
                Spacer()
                Text("Live")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .cornerRadius(4)
            }
            
            if monitor.metrics.isEmpty {
                Text("No metrics yet")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ForEach(section.items, id: \.0) { key, value in
                            HStack {
                                Text(key)
                                    .font(.system(.caption, design: .monospaced))
                                Spacer()
                                Text(value)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if section.title != sections.last?.title {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 240)
    }
}
