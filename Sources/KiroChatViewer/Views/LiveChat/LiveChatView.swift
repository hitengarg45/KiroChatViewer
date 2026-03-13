import SwiftUI
import MarkdownUI

struct LiveChatView: View {
    @StateObject private var vm = LiveChatViewModel()
    @ObservedObject private var theme = ThemeManager.shared
    @FocusState private var inputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            liveChatToolbar
            Divider()
            
            if !vm.isConnected && vm.client.state == .disconnected {
                connectView
            } else if vm.client.state == .connecting {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Connecting to Kiro...")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                chatArea
                
                // Tool approval banner
                if let perm = vm.pendingPermission {
                    toolApprovalBanner(perm: perm)
                }
                
                inputBar
            }
        }
        .background(theme.usesCustomColors ? theme.activeTheme.background : Color.clear)
        .alert("Error", isPresented: .constant(vm.error != nil)) {
            Button("OK") { vm.error = nil }
        } message: {
            Text(vm.error ?? "")
        }
    }
    
    // MARK: - Chat Area (Reversed ScrollView)
    
    private var chatArea: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Newest anchor (visual bottom)
                Color.clear.frame(height: 1)
                    .scaleEffect(x: 1, y: -1)
                
                ForEach(vm.messages.reversed()) { msg in
                    LiveChatMessageView(message: msg)
                        .scaleEffect(x: 1, y: -1)
                }
            }
            .padding()
        }
        .scaleEffect(x: 1, y: -1)
    }
    
    // MARK: - Toolbar
    
    private var liveChatToolbar: some View {
        HStack {
            if vm.isConnected {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("Connected").font(.caption).foregroundStyle(.secondary)
            } else if vm.client.state == .connecting {
                ProgressView().scaleEffect(0.5)
                Text("Connecting...").font(.caption).foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if vm.isConnected {
                Menu {
                    ForEach(Self.availableModels, id: \.0) { id, label in
                        Button(label) { vm.currentModel = id }
                    }
                } label: {
                    Label(vm.currentModel, systemImage: "cpu")
                        .font(.caption)
                }
                
                Button { vm.disconnect() } label: {
                    Image(systemName: "xmark.circle").foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Disconnect")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    // MARK: - Connect View
    
    private var connectView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.purple.opacity(0.5))
            
            Text("Start a Live Chat")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Chat with Kiro directly in the app")
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Working Directory").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text(vm.workingDirectory)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Browse") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        if panel.runModal() == .OK, let url = panel.url {
                            vm.workingDirectory = url.path
                        }
                    }
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(6)
            }
            .frame(maxWidth: 400)
            
            Button {
                vm.connect()
            } label: {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("Connect")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message Kiro...", text: $vm.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($inputFocused)
                .onSubmit {
                    if !NSEvent.modifierFlags.contains(.shift) {
                        vm.send()
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
            
            if vm.isStreaming {
                Button { vm.stop() } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Stop generation")
            } else {
                Button { vm.send() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.purple)
                }
                .buttonStyle(.plain)
                .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Send message")
            }
        }
        .padding(10)
    }
    
    // MARK: - Tool Approval Banner
    
    private func toolApprovalBanner(perm: (id: String, toolName: String, options: [(id: String, name: String)])) -> some View {
        VStack(spacing: 8) {
            Divider()
            HStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title3)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tool Approval Required")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(perm.toolName)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.orange)
                }
                Spacer()
                approvalButtons(options: perm.options)
            }
            .padding(.horizontal, 12)
            Divider()
        }
    }
    
    private func approvalButtons(options: [(id: String, name: String)]) -> some View {
        HStack(spacing: 8) {
            ForEach(options.map { PermOption(optionId: $0.id, name: $0.name) }) { opt in
                if opt.optionId.contains("reject") {
                    Button(opt.name) { vm.respondPermission(optionId: opt.optionId) }
                        .buttonStyle(.bordered)
                        .tint(.red)
                } else {
                    Button(opt.name) { vm.respondPermission(optionId: opt.optionId) }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                }
            }
        }
    }
    
    // MARK: - Models
    
    static let availableModels: [(String, String)] = [
        ("auto", "Auto"),
        ("claude-opus-4.6", "Claude Opus 4.6"),
        ("claude-opus-4.6-1m", "Claude Opus 4.6 1M"),
        ("claude-sonnet-4.6", "Claude Sonnet 4.6"),
        ("claude-sonnet-4.6-1m", "Claude Sonnet 4.6 1M"),
        ("claude-opus-4.5", "Claude Opus 4.5"),
        ("claude-sonnet-4.5", "Claude Sonnet 4.5"),
        ("claude-sonnet-4.5-1m", "Claude Sonnet 4.5 1M"),
        ("claude-sonnet-4", "Claude Sonnet 4"),
        ("claude-haiku-4.5", "Claude Haiku 4.5"),
        ("deepseek-3.2", "DeepSeek 3.2"),
        ("kimi-k2.5", "Kimi K2.5"),
        ("minimax-m2.1", "MiniMax M2.1"),
        ("glm-4.7", "GLM 4.7"),
        ("glm-4.7-flash", "GLM 4.7 Flash"),
        ("qwen3-coder-next", "Qwen3 Coder Next"),
        ("agi-nova-beta-1m", "AGI Nova Beta 1M"),
        ("qwen3-coder-480b", "Qwen3 Coder 480B")
    ]
}

// MARK: - Live Chat Message View

struct LiveChatMessageView: View, Equatable {
    let message: LiveMessage
    @ObservedObject private var theme = ThemeManager.shared
    
    static func == (lhs: LiveChatMessageView, rhs: LiveChatMessageView) -> Bool {
        lhs.message == rhs.message
    }
    
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
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Text("You").font(.headline)
                    Image(systemName: "person.circle.fill").foregroundStyle(.blue)
                }
                Markdown(message.content)
                    .markdownTheme(.kiro)
                    .textSelection(.enabled)
                    .padding()
                    .background(theme.usesCustomColors ? theme.activeTheme.userBubble : Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    private var assistantView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "sparkles").foregroundStyle(.purple)
                    Text("Kiro").font(.headline)
                    if message.isStreaming {
                        ProgressView().scaleEffect(0.5)
                    }
                }
                if message.content.isEmpty && message.isStreaming {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle().fill(.secondary).frame(width: 6, height: 6).opacity(0.5)
                        }
                    }
                    .padding()
                } else {
                    Markdown(message.content)
                        .markdownTheme(.kiro)
                        .textSelection(.enabled)
                        .padding()
                        .background(theme.usesCustomColors ? theme.activeTheme.assistantBubble : Color.purple.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var toolView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(message.toolName ?? "tool")
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.orange)
                    Spacer()
                    if let status = message.toolStatus {
                        Text(status)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(status == "completed" ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                            .foregroundStyle(status == "completed" ? .green : .orange)
                            .cornerRadius(4)
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
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Permission Option Helper

private struct PermOption: Identifiable {
    let id = UUID()
    let optionId: String
    let name: String
}
