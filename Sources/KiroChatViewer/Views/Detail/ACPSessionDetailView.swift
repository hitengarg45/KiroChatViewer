import SwiftUI
import MarkdownUI

struct ACPSessionDetailView: View {
    let session: ACPSession
    let events: [ACPSessionEvent]
    @ObservedObject private var theme = ThemeManager.shared
    @State private var isAtBottom = true
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        Color.clear.frame(height: 1)
                            .scaleEffect(x: 1, y: -1)
                            .id("newest")
                            .onAppear { isAtBottom = true }
                            .onDisappear { isAtBottom = false }
                        
                        ForEach(Array(events.enumerated().reversed()), id: \.offset) { _, event in
                            eventView(event)
                                .scaleEffect(x: 1, y: -1)
                        }
                        
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text(session.title).font(.title)
                            Text(session.cwd)
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Updated: \(session.updatedAt.formatted())")
                                .font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                Label("ACP Session", systemImage: "bolt.fill")
                                    .font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.15))
                                    .foregroundStyle(.purple).cornerRadius(4)
                                Text("\(session.turnCount) turns")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .scaleEffect(x: 1, y: -1)
                    }
                    .padding(.bottom, 40)
                }
                .scaleEffect(x: 1, y: -1)
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
                        .padding()
                    }
                }
            }
        }
        .background(theme.usesCustomColors ? theme.activeTheme.background : Color.clear)
    }
    
    @ViewBuilder
    private func eventView(_ event: ACPSessionEvent) -> some View {
        switch event.kind {
        case "Prompt":
            HStack {
                Spacer(minLength: 60)
                VStack(alignment: .trailing, spacing: 8) {
                    HStack {
                        Text("You").font(.headline)
                        Image(systemName: "person.circle.fill").foregroundStyle(.blue)
                    }
                    Markdown(event.content)
                        .markdownTheme(.kiro)
                        .textSelection(.enabled)
                        .padding()
                        .background(theme.usesCustomColors ? theme.activeTheme.userBubble : Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
        case "AssistantMessage":
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles").foregroundStyle(.purple)
                        Text("Kiro").font(.headline)
                    }
                    Markdown(event.content)
                        .markdownTheme(.kiro)
                        .textSelection(.enabled)
                        .padding()
                        .background(theme.usesCustomColors ? theme.activeTheme.assistantBubble : Color.purple.opacity(0.1))
                        .cornerRadius(8)
                }
                Spacer()
            }
            .padding(.horizontal)
            
        case "ToolResults":
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundStyle(.orange).font(.caption)
                    Text(event.content)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(6)
                Spacer()
            }
            .padding(.horizontal)
            
        default:
            EmptyView()
        }
    }
}
