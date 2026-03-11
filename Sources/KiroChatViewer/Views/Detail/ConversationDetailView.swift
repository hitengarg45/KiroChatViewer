import SwiftUI
import UniformTypeIdentifiers
import MarkdownUI

struct ConversationDetailView: View {
    let conversation: Conversation
    @State private var showExporter = false
    @State private var exportSuccess = false
    @State private var exportError: String?
    @State private var exportDocument: TextDocument?
    @State private var rotationAngle: Double = 0
    @State private var isReloading = false
    @State private var displayedConversation: Conversation?
    @State private var isAtBottom = true
    @EnvironmentObject var db: DatabaseManager
    @ObservedObject private var theme = ThemeManager.shared
    @Binding var selectedConversation: Conversation?
    @EnvironmentObject var titles: TitleManager
    
    private var conv: Conversation {
        displayedConversation ?? conversation
    }
    
    private var displayTitle: String {
        titles.getTitle(for: conv.id) ?? conv.title
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        // Visual bottom anchor (flipped to top)
                        Color.clear.frame(height: 1)
                            .scaleEffect(x: 1, y: -1)
                            .id("newest")
                            .onAppear { isAtBottom = true }
                            .onDisappear { isAtBottom = false }
                        
                        let msgs = conv.messages
                        ForEach(msgs.reversed()) { message in
                            MessageView(message: message)
                                .scaleEffect(x: 1, y: -1)
                        }
                        
                        // Header (visually at top)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(displayTitle)
                                .font(.title)
                            Text(conv.directory)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Updated: \(conv.updatedAt.formatted())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .scaleEffect(x: 1, y: -1)
                    }
                    .padding(.bottom, 40)
                }
                .scaleEffect(x: 1, y: -1)
                .opacity(isReloading ? 0.3 : 1.0)
                .overlay(alignment: .bottomTrailing) {
                    if !isAtBottom {
                        Button {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("newest", anchor: .bottom)
                            }
                        } label: {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white, .purple)
                                .shadow(radius: 4)
                        }
                        .buttonStyle(.plain)
                        .help("Scroll to bottom")
                        .padding()
                        .transition(.opacity)
                    }
                }
            }
            
                if isReloading {
                    ProgressView().scaleEffect(1.5)
                }
            } // ZStack
            
            // Fixed bottom bar — always visible
            Divider()
            HStack {
                Spacer()
                Button(action: continueInTerminal) {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 14))
                        Text("Continue in Terminal")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.purple, in: Capsule())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.vertical, 8)
        } // VStack
        .onAppear {
            displayedConversation = conversation
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation(.linear(duration: 0.5)) { rotationAngle += 360 }
                    isReloading = true
                    Task {
                        if let updated = await db.reloadConversation(id: conv.id) {
                            if let idx = db.conversations.firstIndex(where: { $0.id == updated.id }) {
                                db.conversations[idx] = updated
                            }
                            displayedConversation = updated
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
                Button {
                    exportDocument = TextDocument(text: generateMarkdown())
                    showExporter = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export as Markdown")
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument ?? TextDocument(text: ""),
            contentType: .plainText,
            defaultFilename: "conversation-\(conv.id.prefix(8))-\(Int(Date().timeIntervalSince1970)).md"
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
        .alert(
            "Export Failed",
            isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )
        ) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "Unknown error")
        }
    }
    
    private func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
    
    private func continueInTerminal() {
        let dir = conv.directory
        let sessionId = conv.id
        let dbPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/kiro-cli/data.sqlite3").path
        
        let tmpScript = "/tmp/kiro_resume_\(sessionId.prefix(8)).sh"
        let script = """
        #!/bin/bash
        sqlite3 \(shellEscape(dbPath)) "UPDATE conversations_v2 SET updated_at = CAST(strftime('%s','now') * 1000 AS INTEGER) WHERE conversation_id = \(shellEscape(sessionId))"
        cd \(shellEscape(dir))
        rm -f \(shellEscape(tmpScript))
        exec kiro-cli chat --resume
        """
        try? script.write(toFile: tmpScript, atomically: true, encoding: .utf8)
        
        Task.detached(priority: .userInitiated) {
            let chmod = Process()
            chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmod.arguments = ["+x", tmpScript]
            try? chmod.run()
            chmod.waitUntilExit()
            
            await MainActor.run {
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
        }
    }
    
    private func generateMarkdown() -> String {
        var md = "# \(displayTitle)\n\n"
        md += "**Directory:** \(conv.directory)\n\n"
        md += "**Updated:** \(conv.updatedAt.formatted())\n\n---\n\n"
        for message in conv.messages {
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
