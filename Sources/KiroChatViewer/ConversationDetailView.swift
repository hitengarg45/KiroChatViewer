import SwiftUI
import UniformTypeIdentifiers
import MarkdownUI

struct ConversationDetailView: View {
    let conversation: Conversation
    @State private var exportURL: URL?
    @State private var rotationAngle: Double = 0
    @State private var isReloading = false
    @EnvironmentObject var db: DatabaseManager
    @StateObject private var mdCache = MarkdownCache()
    @Binding var selectedConversation: Conversation?
    
    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(conversation.title)
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
            Button {
                withAnimation(.linear(duration: 0.5)) { rotationAngle += 360 }
                isReloading = true
                Task {
                    await db._loadConversations()
                    selectedConversation = db.conversations.first { $0.id == conversation.id }
                    isReloading = false
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .rotationEffect(.degrees(rotationAngle))
            .help("Refresh conversation")
            
            Spacer()
            
            Button("Export") { exportToMarkdown() }
                .help("Export as Markdown")
        }
        .fileExporter(
            isPresented: .constant(exportURL != nil),
            document: TextDocument(text: generateMarkdown()),
            contentType: .plainText,
            defaultFilename: "conversation.md"
        ) { _ in exportURL = nil }
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
        var md = "# \(conversation.title)\n\n"
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
    
    private func exportToMarkdown() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("conversation-\(conversation.id).md")
        try? generateMarkdown().write(to: tempURL, atomically: true, encoding: .utf8)
        exportURL = tempURL
    }
}

// MARK: - Message View

struct MessageView: View {
    let message: Message
    @ObservedObject var mdCache: MarkdownCache
    
    var body: some View {
        switch message.role {
        case .user:
            userView
        case .tool:
            toolView
        case .assistant:
            assistantView
        }
    }
    
    private var userView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill").foregroundStyle(.blue)
                Text("You").font(.headline)
            }
            Markdown(mdCache.get("user-\(message.id)", content: message.content))
                .markdownTheme(.kiro)
                .textSelection(.enabled)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    private var assistantView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(.purple)
                Text("Kiro").font(.headline)
            }
            Markdown(mdCache.get("asst-\(message.id)", content: message.content))
                .markdownTheme(.kiro)
                .textSelection(.enabled)
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    private var toolView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Show assistant's explanatory text if present
            if !message.content.isEmpty {
                HStack {
                    Image(systemName: "sparkles").foregroundStyle(.purple)
                    Text("Kiro").font(.headline)
                }
                .padding(.horizontal)
                Markdown(mdCache.get("tool-\(message.id)", content: message.content))
                    .markdownTheme(.kiro)
                    .textSelection(.enabled)
                    .padding()
                    .padding(.horizontal)
                    .background(Color.purple.opacity(0.05))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
            
            // Tool calls
            ForEach(message.toolCalls) { call in
                ToolCallView(call: call)
            }
        }
    }
}

// MARK: - Tool Call View

struct ToolCallView: View {
    let call: ToolCall
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Tool header
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text(call.name)
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.orange)
                
                if !call.argsDescription.isEmpty {
                    Text("(\(call.argsDescription))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                
                Spacer()
                
                if let result = call.result {
                    Text(result.status)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(result.status == "Success" ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .foregroundStyle(result.status == "Success" ? .green : .red)
                        .cornerRadius(4)
                }
            }
            
            // Collapsible result
            if let result = call.result, !result.content.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                        Text("Result")
                            .font(.caption)
                        Text("(\(ByteCountFormatter.string(fromByteCount: Int64(result.content.utf8.count), countStyle: .file)))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                if isExpanded {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(result.content.prefix(5000))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                    }
                    .frame(maxHeight: 300)
                    .background(Color(.textBackgroundColor).opacity(0.5))
                    .cornerRadius(6)
                }
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Continue In Terminal Button

struct ContinueInTerminalButton: View {
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 14))
                if isHovering {
                    Text("Continue in Terminal")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, isHovering ? 14 : 10)
            .padding(.vertical, 10)
            .background(Color.purple, in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isHovering = hovering }
        }
    }
}

// MARK: - File Document

struct TextDocument: FileDocument {
    static var readableContentTypes = [UTType.plainText]
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws { text = "" }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: text.data(using: .utf8)!)
    }
}
