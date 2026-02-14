import SwiftUI
import UniformTypeIdentifiers
import MarkdownUI

enum ExportFormat {
    case markdown
    case pdf
}

struct ConversationDetailView: View {
    let conversation: Conversation
    @State private var exportFormat: ExportFormat?
    @State private var showMarkdownExporter = false
    @State private var showPDFExporter = false
    @State private var markdownURL: URL?
    @State private var pdfURL: URL?
    
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
            Menu("Export") {
                Button("Export as Markdown") {
                    exportToMarkdown()
                }
                Button("Export as PDF") {
                    exportToPDF()
                }
            }
        }
        .fileExporter(
            isPresented: $showMarkdownExporter,
            document: TextDocument(text: generateMarkdown()),
            contentType: .plainText,
            defaultFilename: "conversation.md"
        ) { _ in
            markdownURL = nil
        }
        .fileExporter(
            isPresented: $showPDFExporter,
            document: pdfURL != nil ? PDFDocument(url: pdfURL!) : nil,
            contentType: .pdf,
            defaultFilename: "conversation.pdf"
        ) { _ in
            pdfURL = nil
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
        showMarkdownExporter = true
    }
    
    private func exportToPDF() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("conversation-\(conversation.id).pdf")
        
        guard let pdfData = createPDF() else { return }
        try? pdfData.write(to: tempURL)
        pdfURL = tempURL
        showPDFExporter = true
    }
    
    private func createPDF() -> Data? {
        let pageSize = CGSize(width: 612, height: 792) // US Letter
        let pdfData = NSMutableData()
        
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            return nil
        }
        
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }
        
        let margin: CGFloat = 50
        var yPosition: CGFloat = margin
        
        context.beginPage(mediaBox: &mediaBox)
        
        // Title
        let titleFont = NSFont.boldSystemFont(ofSize: 24)
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont]
        let titleString = NSAttributedString(string: conversation.title, attributes: titleAttrs)
        titleString.draw(at: CGPoint(x: margin, y: pageSize.height - yPosition - 30))
        yPosition += 50
        
        // Metadata
        let metaFont = NSFont.systemFont(ofSize: 10)
        let metaAttrs: [NSAttributedString.Key: Any] = [.font: metaFont, .foregroundColor: NSColor.gray]
        let metaString = NSAttributedString(string: "Updated: \(conversation.updatedAt.formatted())", attributes: metaAttrs)
        metaString.draw(at: CGPoint(x: margin, y: pageSize.height - yPosition - 15))
        yPosition += 40
        
        // Messages
        let bodyFont = NSFont.systemFont(ofSize: 11)
        let roleFont = NSFont.boldSystemFont(ofSize: 13)
        
        for message in conversation.messages {
            // Check if we need a new page
            if yPosition > pageSize.height - 150 {
                context.endPage()
                context.beginPage(mediaBox: &mediaBox)
                yPosition = margin
            }
            
            // Role
            let roleAttrs: [NSAttributedString.Key: Any] = [.font: roleFont]
            let roleText = message.role == .user ? "You:" : "Kiro:"
            let roleString = NSAttributedString(string: roleText, attributes: roleAttrs)
            roleString.draw(at: CGPoint(x: margin, y: pageSize.height - yPosition - 18))
            yPosition += 30
            
            // Message content
            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont]
            let bodyString = NSAttributedString(string: message.content, attributes: bodyAttrs)
            
            let maxWidth = pageSize.width - 2 * margin
            let textHeight = bodyString.boundingRect(
                with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin
            ).height
            
            let textRect = CGRect(
                x: margin,
                y: pageSize.height - yPosition - textHeight,
                width: maxWidth,
                height: textHeight
            )
            bodyString.draw(in: textRect)
            yPosition += textHeight + 30
        }
        
        context.endPage()
        context.closePDF()
        
        return pdfData as Data
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

struct PDFDocument: FileDocument {
    static var readableContentTypes = [UTType.pdf]
    var url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    init(configuration: ReadConfiguration) throws {
        url = URL(fileURLWithPath: "")
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: url)
    }
}
