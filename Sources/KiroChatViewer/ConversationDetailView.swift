import SwiftUI
import UniformTypeIdentifiers
import MarkdownUI
import AppKit

struct ConversationDetailView: View {
    let conversation: Conversation
    @State private var showMarkdownExporter = false
    @State private var showPDFExporter = false
    @State private var pdfData: Data?
    
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
                    showMarkdownExporter = true
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
        ) { _ in }
        .fileExporter(
            isPresented: $showPDFExporter,
            document: pdfData != nil ? PDFDataDocument(data: pdfData!) : nil,
            contentType: .pdf,
            defaultFilename: "conversation.pdf"
        ) { _ in
            pdfData = nil
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
    
    private func exportToPDF() {
        pdfData = createPDFData()
        showPDFExporter = true
    }
    
    private func createPDFData() -> Data? {
        // Create attributed string for the entire document
        let fullText = NSMutableAttributedString()
        
        // Title
        let titleFont = NSFont.boldSystemFont(ofSize: 24)
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont]
        fullText.append(NSAttributedString(string: conversation.title + "\n\n", attributes: titleAttrs))
        
        // Metadata
        let metaFont = NSFont.systemFont(ofSize: 10)
        let metaAttrs: [NSAttributedString.Key: Any] = [.font: metaFont, .foregroundColor: NSColor.gray]
        fullText.append(NSAttributedString(string: "Updated: \(conversation.updatedAt.formatted())\n\n", attributes: metaAttrs))
        
        // Messages
        let roleFont = NSFont.boldSystemFont(ofSize: 14)
        let bodyFont = NSFont.systemFont(ofSize: 11)
        
        for message in conversation.messages {
            let roleAttrs: [NSAttributedString.Key: Any] = [.font: roleFont]
            let roleText = message.role == .user ? "You:\n" : "Kiro:\n"
            fullText.append(NSAttributedString(string: roleText, attributes: roleAttrs))
            
            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont]
            fullText.append(NSAttributedString(string: message.content + "\n\n", attributes: bodyAttrs))
        }
        
        // Create PDF from attributed string
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = NSSize(width: 612, height: 792) // US Letter
        printInfo.topMargin = 50
        printInfo.bottomMargin = 50
        printInfo.leftMargin = 50
        printInfo.rightMargin = 50
        
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 512, height: 692))
        textView.textStorage?.setAttributedString(fullText)
        
        let printOperation = NSPrintOperation(view: textView, printInfo: printInfo)
        printOperation.showsPrintPanel = false
        printOperation.showsProgressPanel = false
        
        return textView.dataWithPDF(inside: textView.bounds)
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

struct PDFDataDocument: FileDocument {
    static var readableContentTypes = [UTType.pdf]
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        data = Data()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
