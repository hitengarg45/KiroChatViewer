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
    @ObservedObject private var terminalManager = TerminalSessionManager.shared
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
            // Inline action bar
            HStack(spacing: 8) {
                Text(displayTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                
                Spacer()
                
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
                    Image(systemName: "arrow.clockwise").font(.system(size: 13))
                }
                .buttonStyle(.plain).foregroundStyle(.primary.opacity(0.6))
                .rotationEffect(.degrees(rotationAngle)).help("Refresh")
                
                Button {
                    exportDocument = TextDocument(text: generateMarkdown())
                    showExporter = true
                } label: {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 13))
                }
                .buttonStyle(.plain).foregroundStyle(.primary.opacity(0.6)).help("Export")
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            
            Divider()
            
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
                        VStack(alignment: .leading, spacing: 10) {
                            Text(displayTitle)
                                .font(.title2)
                                .fontWeight(.bold)
                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                    Text(conv.directory.split(separator: "/").last.map(String.init) ?? conv.directory)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(conv.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: "message")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("\(conv.messageCount) messages")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
            
            // Continue in Terminal button (terminal panel is now outside detail view)
            if !terminalManager.isActive(conv.id) {
                continueButton
            }
        } // VStack
        .onAppear {
            displayedConversation = conversation
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
    
    private var continueButton: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                Button { terminalManager.startSession(id: conv.id, directory: conv.directory, command: resumeCommand) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal.fill").font(.system(size: 14))
                        Text("Continue in Terminal").font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.purple, in: Capsule())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    private func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
    
    /// Command that updates updated_at for this conversation then resumes it.
    /// Uses a timestamp slightly in the future to minimize race conditions with
    /// concurrent kiro-cli sessions updating the same directory.
    /// See Docs/TERMINAL_RESUME_HISTORY.md for alternative approaches.
    private var resumeCommand: String {
        let dbPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/kiro-cli/data.sqlite3").path
        return "sqlite3 \(shellEscape(dbPath)) \"UPDATE conversations_v2 SET updated_at = (CAST(strftime('%s','now') AS INTEGER) + 30) * 1000 WHERE conversation_id = \(shellEscape(conv.id))\" && exec kiro-cli chat --resume"
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
