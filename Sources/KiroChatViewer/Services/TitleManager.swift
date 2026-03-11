import Foundation
import SwiftUI

struct TitleEntry: Codable {
    let title: String
    let source: String // "manual" or "auto"
    let generatedAt: Date?
}

class TitleManager: ObservableObject {
    @Published private(set) var titles: [String: TitleEntry] = [:]
    @Published private(set) var pinnedConversations: Set<String> = []
    @Published var isGenerating = false
    @Published var generatingId: String?
    @AppStorage("autoGenerateTitles") var autoGenerateTitles: Bool = true
    @AppStorage("titleModel") var titleModel: String = "qwen3-coder-480b"
    
    private let agentName = "kiro-fast"
    private let maxPerLaunch = 10
    private let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/KiroChatViewer/titles.json")
    private let pinnedURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/KiroChatViewer/pinned.json")
    private let workDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/KiroChatViewer")
    private let agentPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".kiro/agents/kiro-fast.json")
    
    private var generationTask: Task<Void, Never>?
    private var useAgent = true
    
    init() {
        Task.detached(priority: .utility) { [self] in
            let (loadedTitles, loadedPinned) = Self.loadFromDisk(
                fileURL: self.fileURL, pinnedURL: self.pinnedURL
            )
            self.ensureAgentExists()
            await MainActor.run {
                self.titles = loadedTitles
                self.pinnedConversations = loadedPinned
            }
        }
    }
    
    private static func loadFromDisk(fileURL: URL, pinnedURL: URL) -> ([String: TitleEntry], Set<String>) {
        var titles: [String: TitleEntry] = [:]
        var pinned: Set<String> = []
        
        if FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL) {
            if let entries = try? JSONDecoder().decode([String: TitleEntry].self, from: data) {
                titles = entries
            } else if let old = try? JSONDecoder().decode([String: String].self, from: data) {
                titles = old.mapValues { TitleEntry(title: $0, source: "manual", generatedAt: nil) }
            }
        }
        
        if FileManager.default.fileExists(atPath: pinnedURL.path),
           let data = try? Data(contentsOf: pinnedURL),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            pinned = decoded
        }
        
        return (titles, pinned)
    }
    
    // MARK: - Title Access
    
    func getTitle(for conversationId: String) -> String? {
        titles[conversationId]?.title
    }
    
    func setTitle(_ title: String, for conversationId: String) {
        titles[conversationId] = TitleEntry(title: title, source: "manual", generatedAt: Date())
        save()
    }
    
    func hasTitle(for conversationId: String) -> Bool {
        titles[conversationId] != nil
    }
    
    // MARK: - Pin
    
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
    
    // MARK: - Agent Setup
    
    private func ensureAgentExists() {
        guard !FileManager.default.fileExists(atPath: agentPath.path) else { return }
        
        let config = """
        {
          "name": "kiro-fast",
          "description": "Lightweight agent with no MCP servers for fast responses.",
          "tools": [],
          "allowedTools": []
        }
        """
        do {
            try FileManager.default.createDirectory(at: agentPath.deletingLastPathComponent(), withIntermediateDirectories: true)
            try config.write(to: agentPath, atomically: true, encoding: .utf8)
            AppLogger.db.info("Created kiro-fast agent")
        } catch {
            AppLogger.db.error("Failed to create kiro-fast agent: \(error.localizedDescription)")
            useAgent = false
        }
    }
    
    // MARK: - Auto Generation
    
    func startAutoGeneration(for conversations: [Conversation]) {
        guard autoGenerateTitles else { return }
        // Skip if already running
        guard !isGenerating else { return }
        generationTask?.cancel()
        
        // conversations already sorted by updatedAt from DatabaseManager
        let pending = Array(conversations
            .filter { !self.hasTitle(for: $0.id) }
            .prefix(self.maxPerLaunch))
        
        guard !pending.isEmpty else { return }
        AppLogger.db.info("Title generation: \(pending.count) pending (max \(self.maxPerLaunch) per launch)")
        
        let batchSize = 3
        generationTask = Task {
            await MainActor.run { isGenerating = true }
            var batchBuffer: [(String, TitleEntry)] = []
            
            for conv in pending {
                if Task.isCancelled { break }
                await MainActor.run { generatingId = conv.id }
                
                if let title = await generateTitle(for: conv) {
                    batchBuffer.append((conv.id, TitleEntry(title: title, source: "auto", generatedAt: Date())))
                    
                    // Publish in batches
                    if batchBuffer.count >= batchSize {
                        let batch = batchBuffer
                        batchBuffer = []
                        await MainActor.run {
                            for (id, entry) in batch { titles[id] = entry }
                            save()
                        }
                    }
                }
            }
            
            // Flush remaining
            if !batchBuffer.isEmpty {
                let batch = batchBuffer
                await MainActor.run {
                    for (id, entry) in batch { titles[id] = entry }
                    save()
                }
            }
            
            await MainActor.run {
                isGenerating = false
                generatingId = nil
            }
        }
    }
    
    func generateSingleTitle(for conversation: Conversation) {
        Task {
            await MainActor.run { generatingId = conversation.id }
            if let title = await generateTitle(for: conversation) {
                await MainActor.run {
                    titles[conversation.id] = TitleEntry(title: title, source: "auto", generatedAt: Date())
                    save()
                    generatingId = nil
                }
            } else {
                await MainActor.run { generatingId = nil }
            }
        }
    }
    
    func stopGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        generatingId = nil
    }
    
    // MARK: - kiro-cli Integration
    
    private func generateTitle(for conversation: Conversation) async -> String? {
        let messages = conversation.messages
        guard let firstUser = messages.first(where: { $0.role == .user })?.content.prefix(500),
              !firstUser.isEmpty else { return nil }
        
        let firstAssistant = messages.first(where: { $0.role == .assistant })?.content.prefix(500) ?? ""
        
        let prompt = """
        Generate a short title (3-8 words) for this conversation. Output ONLY the title text, nothing else. No quotes, no explanation, no numbering.
        
        User: \(firstUser)
        Assistant: \(firstAssistant)
        """
        
        var args = ["chat", prompt, "--no-interactive", "--trust-tools=", "--model", titleModel, "--wrap", "never"]
        if useAgent {
            args += ["--agent", agentName]
        }
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: findKiroCli() ?? "/usr/local/bin/kiro-cli")
        proc.arguments = args
        proc.currentDirectoryURL = workDir
        
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        
        do {
            try proc.run()
            proc.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }
            
            if let range = output.range(of: "141m> \u{1b}[0m") {
                let after = output[range.upperBound...]
                if let end = after.range(of: "\u{1b}[0m") {
                    let title = String(after[..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty {
                        AppLogger.db.info("Generated title for \(conversation.id): \(title)")
                        return title
                    }
                }
            }
            
            AppLogger.db.error("Failed to parse title from output")
            return nil
        } catch {
            AppLogger.db.error("Title generation failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func findKiroCli() -> String? {
        let paths = [
            NSHomeDirectory() + "/.toolbox/bin/kiro-cli",
            "/opt/homebrew/bin/kiro-cli",
            "/usr/local/bin/kiro-cli",
            "/usr/bin/kiro-cli"
        ]
        return paths.first { FileManager.default.fileExists(atPath: $0) }
    }
    
    // MARK: - Persistence
    
    private func save() {
        let titles = self.titles
        let url = self.fileURL
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard let data = try? JSONEncoder().encode(titles) else { return }
            try? data.write(to: url)
        }
    }
    
    private func savePinned() {
        let pinned = self.pinnedConversations
        let url = self.pinnedURL
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard let data = try? JSONEncoder().encode(pinned) else { return }
            try? data.write(to: url)
        }
    }
}
