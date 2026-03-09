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
    @StateObject private var theme = ThemeManager.shared
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
                    AppLogger.ui.info("Conversation detail appeared, scrolling to bottom")
                    proxy.scrollTo("bottom", anchor: .bottom)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: conversation.id) { _ in
                    AppLogger.ui.info("Conversation changed, scrolling to bottom")
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
                        await db._loadConversations()
                        selectedConversation = db.conversations.first { $0.id == conversation.id }
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

// MARK: - Message View

struct MessageView: View {
    let message: Message
    @ObservedObject var mdCache: MarkdownCache
    @StateObject private var theme = ThemeManager.shared
    
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
        HStack {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 8) {
                HStack {
                    Text("You").font(.headline)
                    Image(systemName: "person.circle.fill").foregroundStyle(.blue)
                }
                Markdown(mdCache.get("user-\(message.id)", content: message.content))
                    .markdownTheme(.kiro)
                    .textSelection(.enabled)
                    .padding()
                    .background(theme.isKiro ? theme.activeTheme.userBubble : Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    private var assistantView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles").foregroundStyle(.purple)
                    Text("Kiro").font(.headline)
                }
                Markdown(mdCache.get("asst-\(message.id)", content: message.content))
                    .markdownTheme(.kiro)
                    .textSelection(.enabled)
                    .padding()
                    .background(theme.isKiro ? theme.activeTheme.assistantBubble : Color.purple.opacity(0.1))
                    .cornerRadius(8)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var toolView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                // Show assistant's explanatory text if present
                if !message.content.isEmpty {
                    HStack {
                        Image(systemName: "sparkles").foregroundStyle(.purple)
                        Text("Kiro").font(.headline)
                    }
                    Markdown(mdCache.get("tool-\(message.id)", content: message.content))
                        .markdownTheme(.kiro)
                        .textSelection(.enabled)
                        .padding()
                        .background(theme.isKiro ? theme.activeTheme.assistantBubble : Color.purple.opacity(0.05))
                        .cornerRadius(8)
                }
                
                // Tool calls
                let toolMode = ThemeManager.shared.toolDisplayMode
                if toolMode != "hidden" {
                    ForEach(message.toolCalls) { call in
                        ToolCallView(call: call, displayMode: toolMode)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Tool Call View

struct ToolCallView: View {
    let call: ToolCall
    let displayMode: String
    @State private var resultExpanded = false
    @State private var isCollapsed: Bool
    
    init(call: ToolCall, displayMode: String) {
        self.call = call
        self.displayMode = displayMode
        self._isCollapsed = State(initialValue: displayMode == "collapsible")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Tool header
            HStack(spacing: 6) {
                if displayMode == "collapsible" {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isCollapsed.toggle() }
                    } label: {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text(call.name)
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.orange)
                
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
            
            if !isCollapsed {
                switch call.name {
                case "execute_bash":
                    BashToolView(call: call, resultExpanded: $resultExpanded)
                case "fs_write":
                    FsWriteToolView(call: call, resultExpanded: $resultExpanded)
                case "fs_read":
                    FsReadToolView(call: call, resultExpanded: $resultExpanded)
                case "grep", "WorkspaceSearch":
                    GrepToolView(call: call, resultExpanded: $resultExpanded)
                case "glob":
                    GlobToolView(call: call, resultExpanded: $resultExpanded)
                case "use_aws":
                    AwsToolView(call: call, resultExpanded: $resultExpanded)
                case "web_search", "web_fetch":
                    WebSearchToolView(call: call, resultExpanded: $resultExpanded)
                case "code":
                    CodeToolView(call: call, resultExpanded: $resultExpanded)
                default:
                    GenericToolArgsView(call: call, resultExpanded: $resultExpanded)
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
    }
}

// MARK: - Bash Tool View

struct BashToolView: View {
    let call: ToolCall
    @Binding var resultExpanded: Bool
    
    var command: String { call.args["command"] as? String ?? "" }
    var workingDir: String? { call.args["working_dir"] as? String ?? call.args["workingDir"] as? String }
    
    private var terminalColors: (bg: Color, fg: Color) {
        switch ThemeManager.shared.terminalStyle {
        case "iterm": return (Color(hex: "#1E1E2E"), Color(hex: "#CDD6F4"))
        case "warp": return (Color(hex: "#16131F"), Color(hex: "#B4A5FF"))
        case "hyper": return (.black, Color(hex: "#50FA7B"))
        default: return (Color(white: 0.95), .black) // macOS Terminal
        }
    }
    
    private var promptColor: Color {
        switch ThemeManager.shared.terminalStyle {
        case "iterm": return Color(hex: "#89B4FA")
        case "warp": return Color(hex: "#7C5BF0")
        case "hyper": return Color(hex: "#50FA7B")
        default: return Color(hex: "#2E7D32")
        }
    }
    
    var body: some View {
        let colors = terminalColors
        VStack(alignment: .leading, spacing: 6) {
            if let dir = workingDir {
                Text(dir)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(promptColor.opacity(0.7))
            }
            
            HStack(alignment: .top, spacing: 6) {
                Text("$")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(promptColor)
                Text(command)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.bg)
            .foregroundStyle(colors.fg)
            .cornerRadius(6)
            .overlay(
                ThemeManager.shared.terminalStyle == "warp" ?
                    RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#7C5BF0").opacity(0.3), lineWidth: 1) : nil
            )
            
            ToolResultView(call: call, resultExpanded: $resultExpanded)
        }
    }
}

// MARK: - fs_write Tool View

struct FsWriteToolView: View {
    let call: ToolCall
    @Binding var resultExpanded: Bool
    
    var command: String { call.args["command"] as? String ?? "" }
    var path: String { call.args["path"] as? String ?? "" }
    var oldStr: String { call.args["old_str"] as? String ?? "" }
    var newStr: String { call.args["new_str"] as? String ?? "" }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // File path
            HStack(spacing: 4) {
                Image(systemName: "doc.text").font(.caption2).foregroundStyle(.blue)
                Text(path).font(.system(.caption, design: .monospaced)).foregroundStyle(.blue)
                Spacer()
                Text(command).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.purple.opacity(0.15)).foregroundStyle(.purple).cornerRadius(3)
            }
            
            if command == "str_replace" && !oldStr.isEmpty {
                // Diff view
                DiffView(oldText: oldStr, newText: newStr)
            } else if command == "create", let content = call.args["file_text"] as? String {
                ScrollView(.vertical, showsIndicators: true) {
                    Text(content)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .background(Color.green.opacity(0.05))
                .cornerRadius(6)
            } else {
                GenericToolArgsView(call: call, resultExpanded: $resultExpanded)
            }
            
            ToolResultView(call: call, resultExpanded: $resultExpanded)
        }
    }
}

// MARK: - Diff View

struct DiffView: View {
    let oldText: String
    let newText: String
    
    private var oldLines: [String] { oldText.components(separatedBy: "\n") }
    private var newLines: [String] { newText.components(separatedBy: "\n") }
    
    private var diffLines: [(type: String, text: String)] {
        let oldSet = Set(oldLines)
        let newSet = Set(newLines)
        var result: [(String, String)] = []
        for line in oldLines {
            result.append((newSet.contains(line) ? "context" : "removed", line))
        }
        for line in newLines where !oldSet.contains(line) {
            result.append(("added", line))
        }
        return result
    }
    
    var body: some View {
        if ThemeManager.shared.diffStyle == "sideBySide" {
            sideBySideView
        } else {
            inlineView
        }
    }
    
    private var inlineView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(diffLines.enumerated()), id: \.offset) { _, line in
                    DiffLineView(prefix: line.type == "removed" ? "−" : line.type == "added" ? "+" : " ",
                                 text: line.text, type: line.type)
                }
            }
        }
        .frame(maxHeight: 250)
        .background(Color(.textBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
    
    private var sideBySideView: some View {
        HStack(alignment: .top, spacing: 1) {
            // Old side
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Old").font(.system(size: 10, weight: .bold)).padding(4).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.05))
                    ForEach(Array(oldLines.enumerated()), id: \.offset) { _, line in
                        let isRemoved = !Set(newLines).contains(line)
                        DiffLineView(prefix: isRemoved ? "−" : " ", text: line, type: isRemoved ? "removed" : "context")
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(.textBackgroundColor).opacity(0.5))
            
            // New side
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("New").font(.system(size: 10, weight: .bold)).padding(4).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.05))
                    ForEach(Array(newLines.enumerated()), id: \.offset) { _, line in
                        let isAdded = !Set(oldLines).contains(line)
                        DiffLineView(prefix: isAdded ? "+" : " ", text: line, type: isAdded ? "added" : "context")
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(.textBackgroundColor).opacity(0.5))
        }
        .frame(maxHeight: 250)
        .cornerRadius(6)
    }
}

struct DiffLineView: View {
    let prefix: String; let text: String; let type: String
    var body: some View {
        HStack(spacing: 4) {
            Text(prefix)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(type == "removed" ? .red : type == "added" ? .green : .secondary)
                .frame(width: 14)
            Text(text.isEmpty ? " " : text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(type == "removed" ? Color.red.opacity(0.1) : type == "added" ? Color.green.opacity(0.1) : Color.clear)
    }
}

// MARK: - fs_read Tool View

struct FsReadToolView: View {
    let call: ToolCall
    @Binding var resultExpanded: Bool
    
    var path: String { call.args["path"] as? String ?? "" }
    var mode: String {
        if let ops = call.args["operations"] as? [[String: Any]], let first = ops.first {
            return first["mode"] as? String ?? ""
        }
        return call.args["mode"] as? String ?? "Line"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text").font(.caption).foregroundStyle(.blue)
                Text(path.isEmpty ? "multiple files" : path)
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(.blue)
                Spacer()
                Text(mode).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1)).foregroundStyle(.blue).cornerRadius(3)
            }
            ToolResultView(call: call, resultExpanded: $resultExpanded)
        }
    }
}

// MARK: - Grep Tool View

struct GrepToolView: View {
    let call: ToolCall
    @Binding var resultExpanded: Bool
    
    var pattern: String { call.args["pattern"] as? String ?? call.args["searchQuery"] as? String ?? "" }
    var searchPath: String { call.args["path"] as? String ?? call.args["searchRoot"] as? String ?? "" }
    var include: String { call.args["include"] as? String ?? "" }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.yellow)
                Text("/\(pattern)/")
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(.yellow)
                if !include.isEmpty {
                    Text(include).font(.caption2).foregroundStyle(.secondary)
                }
            }
            if !searchPath.isEmpty {
                Text("in \(searchPath)")
                    .font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
            }
            ToolResultView(call: call, resultExpanded: $resultExpanded)
        }
    }
}

// MARK: - Glob Tool View

struct GlobToolView: View {
    let call: ToolCall
    @Binding var resultExpanded: Bool
    
    var pattern: String { call.args["pattern"] as? String ?? "" }
    var path: String { call.args["path"] as? String ?? "" }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "folder.badge.magnifyingglass").font(.caption).foregroundStyle(.cyan)
                Text(pattern)
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(.cyan)
            }
            if !path.isEmpty {
                Text("in \(path)")
                    .font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
            }
            ToolResultView(call: call, resultExpanded: $resultExpanded)
        }
    }
}

// MARK: - AWS Tool View

struct AwsToolView: View {
    let call: ToolCall
    @Binding var resultExpanded: Bool
    
    var service: String { call.args["service_name"] as? String ?? "" }
    var operation: String { call.args["operation_name"] as? String ?? "" }
    var region: String { call.args["region"] as? String ?? "" }
    var label: String { call.args["label"] as? String ?? "" }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !label.isEmpty {
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 6) {
                Text("$").font(.system(.caption, design: .monospaced, weight: .bold)).foregroundStyle(.orange)
                Text("aws \(service) \(operation)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.orange)
                if !region.isEmpty {
                    Text("--region \(region)").font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.8))
            .cornerRadius(6)
            
            ToolResultView(call: call, resultExpanded: $resultExpanded)
        }
    }
}

// MARK: - Web Search Tool View

struct WebSearchToolView: View {
    let call: ToolCall
    @Binding var resultExpanded: Bool
    
    var query: String { call.args["query"] as? String ?? call.args["url"] as? String ?? "" }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "globe").font(.caption).foregroundStyle(.blue)
                Text(query)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .lineLimit(2)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(6)
            
            ToolResultView(call: call, resultExpanded: $resultExpanded)
        }
    }
}

// MARK: - Code Tool View

struct CodeToolView: View {
    let call: ToolCall
    @Binding var resultExpanded: Bool
    
    var operation: String { call.args["operation"] as? String ?? "" }
    var symbol: String { call.args["symbol_name"] as? String ?? call.args["pattern"] as? String ?? "" }
    var filePath: String { call.args["file_path"] as? String ?? "" }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right").font(.caption).foregroundStyle(.purple)
                Text(operation).font(.system(.caption, design: .monospaced, weight: .medium)).foregroundStyle(.purple)
                if !symbol.isEmpty {
                    Text(symbol).font(.system(.caption, design: .monospaced)).foregroundStyle(.primary)
                }
            }
            if !filePath.isEmpty {
                Text(filePath).font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
            }
            ToolResultView(call: call, resultExpanded: $resultExpanded)
        }
    }
}

// MARK: - Generic Tool Args View

struct GenericToolArgsView: View {
    let call: ToolCall
    @Binding var resultExpanded: Bool
    
    var body: some View {
        if !call.args.isEmpty {
            Text("Arguments").font(.caption).foregroundStyle(.secondary)
            ScrollView(.vertical, showsIndicators: true) {
                Text(call.fullArgsDescription)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 150)
            .background(Color(.textBackgroundColor).opacity(0.5))
            .cornerRadius(6)
        }
        
        ToolResultView(call: call, resultExpanded: $resultExpanded)
    }
}

// MARK: - Tool Result View

struct ToolResultView: View {
    let call: ToolCall
    @Binding var resultExpanded: Bool
    
    var body: some View {
        if let result = call.result, !result.content.isEmpty {
            HStack {
                Text("Result").font(.caption).foregroundStyle(.secondary)
                Text("(\(ByteCountFormatter.string(fromByteCount: Int64(result.content.utf8.count), countStyle: .file)))")
                    .font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { resultExpanded.toggle() }
                } label: {
                    Text(resultExpanded ? "Show Less" : "Show More").font(.caption2).foregroundStyle(.blue)
                }.buttonStyle(.plain)
            }
            ScrollView(.vertical, showsIndicators: true) {
                Text(result.content)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: resultExpanded ? 600 : 120)
            .background(Color(.textBackgroundColor).opacity(0.5))
            .cornerRadius(6)
        }
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
