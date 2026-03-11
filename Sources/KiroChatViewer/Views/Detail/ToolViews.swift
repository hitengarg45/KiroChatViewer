import SwiftUI
import UniformTypeIdentifiers
import MarkdownUI

// MARK: - Terminal Color Palette (static, no per-render parsing)

private enum TerminalPalette {
    static let itermBg = Color(hex: "#1E1E2E")
    static let itermFg = Color(hex: "#CDD6F4")
    static let itermPrompt = Color(hex: "#89B4FA")
    static let warpBg = Color(hex: "#16131F")
    static let warpFg = Color(hex: "#B4A5FF")
    static let warpPrompt = Color(hex: "#7C5BF0")
    static let hyperFg = Color(hex: "#50FA7B")
    static let terminalPrompt = Color(hex: "#2E7D32")
    
    static func colors(for style: String) -> (bg: Color, fg: Color, prompt: Color) {
        switch style {
        case "iterm": return (itermBg, itermFg, itermPrompt)
        case "warp": return (warpBg, warpFg, warpPrompt)
        case "hyper": return (.black, hyperFg, hyperFg)
        default: return (Color(white: 0.95), .black, terminalPrompt)
        }
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
        .onChange(of: displayMode) { newMode in
            isCollapsed = (newMode == "collapsible")
        }
    }
}

// MARK: - Bash Tool View

struct BashToolView: View {
    let call: ToolCall
    @Binding var resultExpanded: Bool
    @ObservedObject private var theme = ThemeManager.shared
    
    var command: String { call.args["command"] as? String ?? "" }
    var workingDir: String? { call.args["working_dir"] as? String ?? call.args["workingDir"] as? String }
    
    var body: some View {
        let palette = TerminalPalette.colors(for: theme.terminalStyle)
        VStack(alignment: .leading, spacing: 6) {
            if let dir = workingDir {
                Text(dir)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(palette.prompt.opacity(0.7))
            }
            
            HStack(alignment: .top, spacing: 6) {
                Text("$")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(palette.prompt)
                Text(command)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.bg)
            .foregroundStyle(palette.fg)
            .cornerRadius(6)
            .overlay(
                theme.terminalStyle == "warp" ?
                    RoundedRectangle(cornerRadius: 6).stroke(TerminalPalette.warpPrompt.opacity(0.3), lineWidth: 1) : nil
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
            HStack(spacing: 4) {
                Image(systemName: "doc.text").font(.caption2).foregroundStyle(.blue)
                Text(path).font(.system(.caption, design: .monospaced)).foregroundStyle(.blue)
                Spacer()
                Text(command).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.purple.opacity(0.15)).foregroundStyle(.purple).cornerRadius(3)
            }
            
            if command == "str_replace" && !oldStr.isEmpty {
                DiffView(oldText: oldStr, newText: newStr)
            } else if command == "create", let content = call.args["file_text"] as? String {
                ScrollView(.vertical, showsIndicators: true) {
                    Text(content)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
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
    @ObservedObject private var theme = ThemeManager.shared
    
    private var oldLines: [String] { oldText.components(separatedBy: "\n") }
    private var newLines: [String] { newText.components(separatedBy: "\n") }
    
    private var diffResult: [DiffLine] {
        DiffComputer.compute(old: oldLines, new: newLines)
    }
    
    var body: some View {
        if theme.diffStyle == "sideBySide" {
            sideBySideView
        } else {
            inlineView
        }
    }
    
    private var inlineView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(diffResult) { line in
                    DiffLineView(prefix: line.prefix, text: line.text, type: line.type)
                }
            }
        }
        .frame(maxHeight: 250)
        .background(Color(.textBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
    
    private var sideBySideView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 1) {
                    Text("Old").font(.system(size: 10, weight: .bold)).padding(4).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.05))
                    Text("New").font(.system(size: 10, weight: .bold)).padding(4).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.05))
                }
                ForEach(diffResult) { line in
                    HStack(spacing: 1) {
                        // Left column
                        Group {
                            if line.type == "removed" || line.type == "context" {
                                DiffLineView(prefix: line.type == "removed" ? "−" : " ", text: line.text, type: line.type)
                            } else {
                                Color.clear.frame(height: 18)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        // Right column
                        Group {
                            if line.type == "added" || line.type == "context" {
                                DiffLineView(prefix: line.type == "added" ? "+" : " ", text: line.text, type: line.type)
                            } else {
                                Color.clear.frame(height: 18)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(maxHeight: 250)
        .cornerRadius(6)
    }
}

// MARK: - LCS-based Diff

struct DiffLine: Identifiable {
    let id = UUID()
    let type: String // "context", "added", "removed"
    let text: String
    var prefix: String {
        switch type {
        case "removed": return "−"
        case "added": return "+"
        default: return " "
        }
    }
}

private enum DiffComputer {
    static func compute(old: [String], new: [String]) -> [DiffLine] {
        let lcs = longestCommonSubsequence(old, new)
        var result: [DiffLine] = []
        var oi = 0, ni = 0, li = 0
        
        while oi < old.count || ni < new.count {
            if li < lcs.count && oi < old.count && old[oi] == lcs[li]
                && ni < new.count && new[ni] == lcs[li] {
                result.append(DiffLine(type: "context", text: lcs[li]))
                oi += 1; ni += 1; li += 1
            } else if oi < old.count && (li >= lcs.count || old[oi] != lcs[li]) {
                result.append(DiffLine(type: "removed", text: old[oi]))
                oi += 1
            } else if ni < new.count && (li >= lcs.count || new[ni] != lcs[li]) {
                result.append(DiffLine(type: "added", text: new[ni]))
                ni += 1
            }
        }
        return result
    }
    
    private static func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
        let m = a.count, n = b.count
        guard m > 0 && n > 0 else { return [] }
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                dp[i][j] = a[i-1] == b[j-1] ? dp[i-1][j-1] + 1 : max(dp[i-1][j], dp[i][j-1])
            }
        }
        var result: [String] = []
        var i = m, j = n
        while i > 0 && j > 0 {
            if a[i-1] == b[j-1] { result.append(a[i-1]); i -= 1; j -= 1 }
            else if dp[i-1][j] > dp[i][j-1] { i -= 1 }
            else { j -= 1 }
        }
        return result.reversed()
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
        VStack(alignment: .leading, spacing: 6) {
            if !call.args.isEmpty {
                Text("Arguments").font(.caption).foregroundStyle(.secondary)
                ScrollView(.vertical, showsIndicators: true) {
                    Text(call.fullArgsDescription)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxHeight: 150)
                .background(Color(.textBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            }
            
            ToolResultView(call: call, resultExpanded: $resultExpanded)
        }
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
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
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
        guard let data = text.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
