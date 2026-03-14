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
    @State private var terminalHeight: CGFloat = 300
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
            
            // Embedded terminal or Continue button
            if terminalManager.isActive(conv.id) {
                terminalPanel
            } else {
                continueButton
            }
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
    
    @State private var isDraggingTerminal = false
    
    private var terminalPanel: some View {
        VStack(spacing: 0) {
            // Drag handle (only when not minimized)
            if !terminalManager.isMinimized(conv.id) {
                Rectangle()
                    .fill(isDraggingTerminal ? Color.purple : Color.secondary.opacity(0.3))
                    .frame(height: 3)
                    .contentShape(Rectangle().size(width: 10000, height: 12))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingTerminal = true
                                terminalHeight = max(150, min(600, terminalHeight - value.translation.height))
                            }
                            .onEnded { _ in isDraggingTerminal = false }
                    )
                    .onHover { h in if h { NSCursor.resizeUpDown.push() } else { NSCursor.pop() } }
            }
            
            // Terminal container
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.purple)
                    Text("Terminal")
                        .font(.system(size: 11, weight: .semibold))
                    
                    Text(conv.directory.split(separator: "/").last.map(String.init) ?? "")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Minimize
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { terminalManager.toggleMinimize(conv.id) }
                    } label: {
                        Image(systemName: terminalManager.isMinimized(conv.id) ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help(terminalManager.isMinimized(conv.id) ? "Expand" : "Minimize")
                    
                    // Resize
                    if !terminalManager.isMinimized(conv.id) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { terminalHeight = terminalHeight < 400 ? 500 : 250 }
                        } label: {
                            Image(systemName: terminalHeight < 400 ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary).help("Toggle size")
                    }
                    
                    // Close
                    Button { terminalManager.closeSession(id: conv.id) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Close terminal")
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                
                // Terminal content (hidden when minimized)
                if !terminalManager.isMinimized(conv.id) {
                    Divider()
                    
                    if let tv = terminalManager.terminalView(for: conv.id) {
                        EmbeddedTerminalView(terminalView: tv)
                            .frame(height: terminalHeight)
                            .padding(.leading, 4)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
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
