import SwiftUI
import UniformTypeIdentifiers
import MarkdownUI

struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ConversationDetailView: View {
    let conversation: Conversation
    @State private var exportURL: URL?
    @State private var rotationAngle: Double = 0
    @State private var isReloading = false
    @State private var showScrollButton = false
    @EnvironmentObject var db: DatabaseManager
    @Binding var selectedConversation: Conversation?
    
    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
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
                        
                        // Top anchor - when visible, we're scrolled up
                        Color.clear
                            .frame(height: 1)
                            .id("top")
                        
                        ForEach(conversation.messages) { message in
                            MessageView(message: message)
                        }
                        
                        // Bottom anchor - when visible, we're at bottom
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                            .onAppear {
                                showScrollButton = false
                            }
                            .onDisappear {
                                showScrollButton = true
                            }
                    }
                    .padding(.bottom, 40)
                }
                .opacity(isReloading ? 0.3 : 1.0)
                .onAppear {
                    // Jump to bottom immediately (no animation) when conversation first appears
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                .overlay(alignment: .bottomTrailing) {
                    if showScrollButton {
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }) {
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
            
            if isReloading {
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
        .toolbar {
            Button(action: {
                withAnimation(.linear(duration: 0.5)) {
                    rotationAngle += 360
                }
                
                isReloading = true
                
                Task {
                    db.loadConversations()
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                    
                    await MainActor.run {
                        let id = conversation.id
                        selectedConversation = db.conversations.first { $0.id == id }
                        isReloading = false
                    }
                }
            }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .rotationEffect(.degrees(rotationAngle))
            
            Button("Export") {
                exportToMarkdown()
            }
        }
        .fileExporter(
            isPresented: .constant(exportURL != nil),
            document: TextDocument(text: generateMarkdown()),
            contentType: .plainText,
            defaultFilename: "conversation.md"
        ) { _ in
            exportURL = nil
        }
    }
    
    private func generateMarkdown() -> String {
        var md = "# \(conversation.title)\n\n"
        md += "**Directory:** \(conversation.directory)\n\n"
        md += "**Updated:** \(conversation.updatedAt.formatted())\n\n"
        md += "---\n\n"
        
        for message in conversation.messages {
            md += "## \(message.role == .user ? "User" : "Assistant")\n\n"
            md += message.content + "\n\n"
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

struct MessageView: View {
    let message: Message
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: message.role == .user ? "person.circle.fill" : "sparkles")
                    .foregroundStyle(message.role == .user ? .blue : .purple)
                Text(message.role == .user ? "You" : "Kiro")
                    .font(.headline)
            }
            
            Markdown(message.content)
                .textSelection(.enabled)
                .padding()
                .background(message.role == .user ? Color.blue.opacity(0.1) : Color.purple.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(.horizontal)
    }
}

struct TextDocument: FileDocument {
    static var readableContentTypes = [UTType.plainText]
    var text: String
    
    init(text: String) {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        text = ""
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: text.data(using: .utf8)!)
    }
}
