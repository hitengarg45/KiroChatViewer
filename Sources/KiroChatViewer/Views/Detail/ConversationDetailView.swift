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
    @StateObject private var mdCache = MarkdownCache()
    @ObservedObject private var theme = ThemeManager.shared
    @Binding var selectedConversation: Conversation?
    @EnvironmentObject var titles: TitleManager
    
    private var displayTitle: String {
        titles.getTitle(for: conversation.id) ?? conversation.title
    }
    
    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
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
                        
                        Divider()
                        
                        Color.clear.frame(height: 1).id("top")
                        
                        ForEach(conversation.messages) { message in
                            MessageView(message: message, mdCache: mdCache)
                        }
                        
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.bottom, 40)
                }
                .opacity(isReloading ? 0.3 : 1.0)
                .onAppear {
                    proxy.scrollTo("bottom", anchor: .bottom)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: conversation.id) { _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    ContinueInTerminalButton { continueInTerminal() }
                        .padding()
                        .padding(.bottom, 52)
                }
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
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
                }
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
                Button { 
                    AppLogger.ui.info("Export button clicked")
                    showExporter = true 
                } label: {
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
                AppLogger.ui.error("Export failed: \(error.localizedDescription)")
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
            if let error = exportError {
                Text(error)
            }
        }
    }
    
    private func continueInTerminal() {
        let dir = conversation.directory
        let sessionId = conversation.id
        let dbPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/kiro-cli/data.sqlite3").path
        
        // Temp script: touch updated_at to make this session the latest, then resume
        let tmpScript = "/tmp/kiro_resume_\(sessionId.prefix(8)).sh"
        let script = """
        #!/bin/bash
        # Make this session the most recent so --resume picks it
        sqlite3 '\(dbPath)' "UPDATE conversations_v2 SET updated_at = CAST(strftime('%s','now') * 1000 AS INTEGER) WHERE conversation_id = '\(sessionId)'"
        cd '\(dir)'
        rm -f '\(tmpScript)'
        exec kiro-cli chat --resume
        """
        try? script.write(toFile: tmpScript, atomically: true, encoding: .utf8)
        
        // Make executable and run in Terminal
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
        AppLogger.ui.info("Generating markdown for conversation: \(conversation.id)")
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
        AppLogger.ui.info("Markdown generated: \(md.count) characters, \(conversation.messages.count) messages")
        return md
    }
}

