import SwiftUI
import UniformTypeIdentifiers
import MarkdownUI

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
