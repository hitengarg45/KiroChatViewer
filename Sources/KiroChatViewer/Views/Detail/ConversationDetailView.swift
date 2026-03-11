import SwiftUI
import UniformTypeIdentifiers
import MarkdownUI

struct ConversationDetailView: View {
    let conversation: Conversation
    @State private var showExporter = false
    @State private var exportSuccess = false
    @State private var exportError: String?
    @State private var rotationAngle: Double = 0
    @State private var isReloading = false
    @EnvironmentObject var db: DatabaseManager
    @ObservedObject private var theme = ThemeManager.shared
    @Binding var selectedConversation: Conversation?
    @EnvironmentObject var titles: TitleManager
    
    private var displayTitle: String {
        titles.getTitle(for: conversation.id) ?? conversation.title
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    // Bottom anchor (visually at bottom due to flip)
                    Color.clear.frame(height: 1)
                        .scaleEffect(x: 1, y: -1)
                    
                    // Messages in reverse order — newest first in the flipped list
                    let msgs = conversation.messages
                    ForEach(Array(msgs.reversed().enumerated()), id: \.element.id) { _, message in
                        MessageView(message: message)
                            .scaleEffect(x: 1, y: -1)
                    }
                    
                    // Header (visually at top due to flip)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(displayTitle)
                            .font(.title)
                        Text(conversation.directory)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Updated: \(conversation.updatedAt.formatted())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .scaleEffect(x: 1, y: -1)
                }
                .padding(.bottom, 40)
            }
            .scaleEffect(x: 1, y: -1) // Flip entire ScrollView
            .opacity(isReloading ? 0.3 : 1.0)
            .overlay(alignment: .bottomTrailing) {
                ContinueInTerminalButton { continueInTerminal() }
                    .padding()
            }
            
            if isReloading {
                ProgressView().scaleEffect(1.5)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation(.linear(duration: 0.5)) { rotationAngle += 360 }
                    isReloading = true
                    Task {
                        if let updated = await db.reloadConversation(id: conversation.id) {
                            if let idx = db.conversations.firstIndex(where: { $0.id == updated.id }) {
                                db.conversations[idx] = updated
                            }
                            selectedConversation = updated
                        }
                        isReloading = false
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .rotationEffect(.degrees(rotationAngle))
                .help("Refresh conversation")
            }
            
            ToolbarItem(placement: .automatic) {
                Button { showExporter = true } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export as Markdown")
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: TextDocument(text: generateMarkdown()),
            contentType: .plainText,
            defaultFilename: "conversation-\(conversation.id.prefix(8))-\(Date().timeIntervalSince1970).md"
        ) { result in
            switch result {
            case .success(let url):
                AppLogger.ui.info("Export successful: \(url.path)")
                exportSuccess = true
            case .failure(let error):
                exportError = error.localizedDescription
            }
        }
        .alert("Export Successful", isPresented: $exportSuccess) {
            Button("OK") { }
        } message: {
            Text("Conversation exported successfully")
        }
        .alert("Export Failed", isPresented: .constant(exportError != nil)) {
            Button("OK") { exportError = nil }
        } message: {
            if let error = exportError { Text(error) }
        }
    }
    
    private func continueInTerminal() {
        let dir = conversation.directory
        let sessionId = conversation.id
        let dbPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/kiro-cli/data.sqlite3").path
        
        let tmpScript = "/tmp/kiro_resume_\(sessionId.prefix(8)).sh"
        let script = """
        #!/bin/bash
        sqlite3 '\(dbPath)' "UPDATE conversations_v2 SET updated_at = CAST(strftime('%s','now') * 1000 AS INTEGER) WHERE conversation_id = '\(sessionId)'"
        cd '\(dir)'
        rm -f '\(tmpScript)'
        exec kiro-cli chat --resume
        """
        try? script.write(toFile: tmpScript, atomically: true, encoding: .utf8)
        
        let chmod = Process()
        chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmod.arguments = ["+x", tmpScript]
        try? chmod.run()
        chmod.waitUntilExit()
        
        let appleScript = """
        tell application "Terminal"
            activate
            do script "'\(tmpScript)'"
        end tell
        """
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", appleScript]
        try? proc.run()
    }
    
    private func generateMarkdown() -> String {
        var md = "# \(displayTitle)\n\n"
        md += "**Directory:** \(conversation.directory)\n\n"
        md += "**Updated:** \(conversation.updatedAt.formatted())\n\n---\n\n"
        for message in conversation.messages {
            switch message.role {
            case .user:
                md += "## You\n\n\(message.content)\n\n"
            case .tool:
                if !message.content.isEmpty { md += "> \(message.content)\n\n" }
                for tc in message.toolCalls {
                    md += "### 🔧 \(tc.name)\n\n"
                    if !tc.argsDescription.isEmpty { md += "**Args:** \(tc.argsDescription)\n\n" }
                    if let r = tc.result { md += "<details><summary>Result (\(r.status))</summary>\n\n```\n\(r.content.prefix(2000))\n```\n</details>\n\n" }
                }
            case .assistant:
                md += "## Kiro\n\n\(message.content)\n\n"
            }
        }
        return md
    }
}
