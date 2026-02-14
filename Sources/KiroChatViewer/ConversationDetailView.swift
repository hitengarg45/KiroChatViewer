import SwiftUI
import UniformTypeIdentifiers

struct ConversationDetailView: View {
    let conversation: Conversation
    @State private var exportURL: URL?
    
    var body: some View {
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
                
                ForEach(conversation.messages) { message in
                    MessageView(message: message)
                }
            }
        }
        .toolbar {
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
            
            Text(message.content)
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
