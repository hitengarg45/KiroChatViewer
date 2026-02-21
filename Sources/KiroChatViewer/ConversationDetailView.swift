import SwiftUI
import UniformTypeIdentifiers
import MarkdownUI

struct ConversationDetailView: View {
    let conversation: Conversation
    @State private var showMarkdownExporter = false
    @State private var showHTMLExporter = false
    @State private var markdownContent: String?
    @State private var htmlContent: String?
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
            
            Menu {
                Button("Export as Markdown") { exportToMarkdown() }
                Button("Export as HTML") { exportToHTML() }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export conversation")
        }
        .fileExporter(
            isPresented: $showMarkdownExporter,
            document: markdownContent.map { MarkdownDocument(text: $0) },
            contentType: .plainText,
            defaultFilename: "conversation.md"
        ) { result in
            showMarkdownExporter = false
            markdownContent = nil
        }
        .fileExporter(
            isPresented: $showHTMLExporter,
            document: htmlContent.map { HTMLDocument(text: $0) },
            contentType: .html,
            defaultFilename: "conversation.html"
        ) { result in
            showHTMLExporter = false
            htmlContent = nil
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
        markdownContent = generateMarkdown()
        showMarkdownExporter = true
    }
    
    private func exportToHTML() {
        htmlContent = generateHTML()
        showHTMLExporter = true
    }
    
    private func generateHTML() -> String {
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(conversation.title)</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    padding: 20px;
                    min-height: 100vh;
                }
                .container {
                    max-width: 900px;
                    margin: 0 auto;
                    background: white;
                    border-radius: 16px;
                    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                    overflow: hidden;
                }
                .header {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 30px;
                    text-align: center;
                }
                .header h1 { font-size: 28px; margin-bottom: 10px; }
                .header .meta { opacity: 0.9; font-size: 14px; }
                .messages { padding: 30px; }
                .message {
                    margin-bottom: 24px;
                    padding: 20px;
                    border-radius: 12px;
                    animation: fadeIn 0.3s ease-in;
                }
                @keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
                .user {
                    background: linear-gradient(135deg, #667eea15, #764ba215);
                    border-left: 4px solid #667eea;
                }
                .assistant {
                    background: linear-gradient(135deg, #f093fb15, #f5576c15);
                    border-left: 4px solid #f093fb;
                }
                .tool {
                    background: #f8f9fa;
                    border-left: 4px solid #ffa500;
                }
                .role {
                    font-weight: 600;
                    font-size: 14px;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                    margin-bottom: 12px;
                    display: flex;
                    align-items: center;
                    gap: 8px;
                }
                .user .role { color: #667eea; }
                .assistant .role { color: #f093fb; }
                .tool .role { color: #ffa500; }
                .content {
                    white-space: pre-wrap;
                    word-wrap: break-word;
                    font-size: 15px;
                }
                code {
                    background: #f4f4f4;
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-family: 'Monaco', 'Courier New', monospace;
                    font-size: 13px;
                }
                .tool-call {
                    background: white;
                    padding: 12px;
                    border-radius: 8px;
                    margin-top: 12px;
                    border: 1px solid #e0e0e0;
                }
                .tool-name {
                    font-weight: 600;
                    color: #ffa500;
                    margin-bottom: 8px;
                    font-size: 14px;
                }
                .tool-args, .tool-result {
                    font-size: 13px;
                    margin-top: 8px;
                    padding: 8px;
                    background: #f8f9fa;
                    border-radius: 4px;
                    font-family: 'Monaco', 'Courier New', monospace;
                    white-space: pre-wrap;
                    word-break: break-all;
                }
                .footer {
                    text-align: center;
                    padding: 20px;
                    color: #666;
                    font-size: 13px;
                    border-top: 1px solid #eee;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>\(conversation.title)</h1>
                    <div class="meta">
                        <div>\(conversation.directory)</div>
                        <div>Updated: \(conversation.updatedAt.formatted())</div>
                    </div>
                </div>
                <div class="messages">
        """
        
        for message in conversation.messages {
            let roleClass: String
            let roleIcon: String
            let roleName: String
            
            switch message.role {
            case .user:
                roleClass = "user"
                roleIcon = "👤"
                roleName = "You"
            case .assistant:
                roleClass = "assistant"
                roleIcon = "✨"
                roleName = "Kiro"
            case .tool:
                roleClass = "tool"
                roleIcon = "🔧"
                roleName = "Tool"
            }
            
            html += """
                    <div class="message \(roleClass)">
                        <div class="role">\(roleIcon) \(roleName)</div>
                        <div class="content">\(message.content.htmlEscaped)</div>
            """
            
            for tc in message.toolCalls {
                html += """
                        <div class="tool-call">
                            <div class="tool-name">🔧 \(tc.name)</div>
                """
                if !tc.argsDescription.isEmpty {
                    html += """
                            <div class="tool-args"><strong>Args:</strong><br>\(tc.argsDescription.htmlEscaped)</div>
                    """
                }
                if let r = tc.result {
                    html += """
                            <div class="tool-result"><strong>Result (\(r.status)):</strong><br>\(String(r.content.prefix(1000)).htmlEscaped)</div>
                    """
                }
                html += "</div>"
            }
            
            html += "</div>"
        }
        
        html += """
                </div>
                <div class="footer">
                    Exported from KiroChatViewer • \(Date().formatted())
                </div>
            </div>
        </body>
        </html>
        """
        
        return html
    }
}

// MARK: - Message View

extension String {
    var htmlEscaped: String {
        self.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

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

// MARK: - File Documents

struct MarkdownDocument: FileDocument {
    static var readableContentTypes = [UTType.plainText]
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws { text = "" }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: text.data(using: .utf8)!)
    }
}

struct HTMLDocument: FileDocument {
    static var readableContentTypes = [UTType.html]
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws { text = "" }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: text.data(using: .utf8)!)
    }
}
