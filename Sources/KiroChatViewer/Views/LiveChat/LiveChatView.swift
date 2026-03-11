import SwiftUI
import MarkdownUI

struct LiveChatView: View {
    @StateObject private var vm = LiveChatViewModel()
    @ObservedObject private var theme = ThemeManager.shared
    @FocusState private var inputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
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
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(vm.messages) { msg in
                                liveChatMessage(msg)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding()
                    }
                    .onChange(of: vm.messages.count) { _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
                
                Divider()
                
                // Input
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
                // Model picker
                Menu {
                    Button("qwen3-coder-480b (0.01x)") { vm.currentModel = "qwen3-coder-480b" }
                    Button("claude-haiku-4.5 (0.40x)") { vm.currentModel = "claude-haiku-4.5" }
                    Button("claude-sonnet-4 (1.30x)") { vm.currentModel = "claude-sonnet-4" }
                    Button("claude-sonnet-4.5 (1.30x)") { vm.currentModel = "claude-sonnet-4.5" }
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
    
    // MARK: - Message
    
    @ViewBuilder
    private func liveChatMessage(_ msg: LiveMessage) -> some View {
        switch msg.role {
        case "user":
            HStack {
                Spacer(minLength: 60)
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Text("You").font(.caption).fontWeight(.medium)
                        Image(systemName: "person.circle.fill").foregroundStyle(.blue).font(.caption)
                    }
                    Text(msg.content)
                        .textSelection(.enabled)
                        .padding(10)
                        .background(theme.usesCustomColors ? theme.activeTheme.userBubble : Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
        case "tool":
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver.fill").foregroundStyle(.orange).font(.caption)
                Text(msg.toolName ?? "tool").font(.system(.caption, design: .monospaced)).foregroundStyle(.orange)
                if let status = msg.toolStatus {
                    Text(status).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(6)
            .background(Color.orange.opacity(0.05))
            .cornerRadius(6)
            
        default: // assistant
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "sparkles").foregroundStyle(.purple).font(.caption)
                        Text("Kiro").font(.caption).fontWeight(.medium)
                        if msg.isStreaming {
                            ProgressView().scaleEffect(0.4)
                        }
                    }
                    if msg.content.isEmpty && msg.isStreaming {
                        HStack(spacing: 4) {
                            ForEach(0..<3) { i in
                                Circle().fill(.secondary).frame(width: 6, height: 6)
                                    .opacity(0.5)
                            }
                        }
                        .padding(10)
                    } else {
                        Markdown(msg.content)
                            .markdownTheme(.kiro)
                            .textSelection(.enabled)
                            .padding(10)
                            .background(theme.usesCustomColors ? theme.activeTheme.assistantBubble : Color.purple.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                Spacer()
            }
        }
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
}
