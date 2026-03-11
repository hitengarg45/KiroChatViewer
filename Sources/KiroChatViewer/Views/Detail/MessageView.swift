import SwiftUI
import MarkdownUI

// MARK: - Message View

struct MessageView: View {
    let message: Message
    @ObservedObject var mdCache: MarkdownCache
    @ObservedObject private var theme = ThemeManager.shared
    
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
                    .background(theme.usesCustomColors ? theme.activeTheme.userBubble : Color.blue.opacity(0.1))
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
                    .background(theme.usesCustomColors ? theme.activeTheme.assistantBubble : Color.purple.opacity(0.1))
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
                        .background(theme.usesCustomColors ? theme.activeTheme.assistantBubble : Color.purple.opacity(0.05))
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
