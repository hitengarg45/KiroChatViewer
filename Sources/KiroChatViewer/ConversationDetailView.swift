import SwiftUI
import UniformTypeIdentifiers
import MarkdownUI
import AppKit
import PDFKit

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
        let pdfData = NSMutableData()
        
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - (2 * margin)
        let contentHeight = pageHeight - (2 * margin)
        
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return nil }
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }
        
        let titleFont = NSFont.boldSystemFont(ofSize: 24)
        let metaFont = NSFont.systemFont(ofSize: 10)
        let roleFont = NSFont.boldSystemFont(ofSize: 14)
        let bodyFont = NSFont.systemFont(ofSize: 11)
        
        var yPosition: CGFloat = margin
        
        context.beginPage(mediaBox: &mediaBox)
        
        // Title
        let titleText = NSAttributedString(string: conversation.title, attributes: [.font: titleFont])
        let titleSize = titleText.size()
        titleText.draw(at: CGPoint(x: margin, y: pageHeight - yPosition - titleSize.height))
        yPosition += titleSize.height + 20
        
        // Metadata
        let metaText = NSAttributedString(string: "Updated: \(conversation.updatedAt.formatted())", 
                                         attributes: [.font: metaFont, .foregroundColor: NSColor.gray])
        let metaSize = metaText.size()
        metaText.draw(at: CGPoint(x: margin, y: pageHeight - yPosition - metaSize.height))
        yPosition += metaSize.height + 30
        
        // Messages
        for message in conversation.messages {
            if yPosition > contentHeight - 100 {
                context.endPage()
                context.beginPage(mediaBox: &mediaBox)
                yPosition = margin
            }
            
            let roleText = NSAttributedString(string: message.role == .user ? "You:" : "Kiro:", 
                                             attributes: [.font: roleFont])
            let roleSize = roleText.size()
            roleText.draw(at: CGPoint(x: margin, y: pageHeight - yPosition - roleSize.height))
            yPosition += roleSize.height + 10
            
            let bodyText = NSAttributedString(string: message.content, attributes: [.font: bodyFont])
            let bodySize = bodyText.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), 
                                                 options: [.usesLineFragmentOrigin, .usesFontLeading])
            
            if yPosition + bodySize.height > contentHeight {
                context.endPage()
                context.beginPage(mediaBox: &mediaBox)
                yPosition = margin
            }
            
            bodyText.draw(in: CGRect(x: margin, y: pageHeight - yPosition - bodySize.height, 
                                    width: contentWidth, height: bodySize.height))
            yPosition += bodySize.height + 25
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
    static var readableContentTypes: [UTType] = [.plainText]
    static var writableContentTypes: [UTType] = [.plainText]
    
    var text: String
    
    init(text: String) {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            text = string
        } else {
            text = ""
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}

struct PDFDataDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.pdf]
    static var writableContentTypes: [UTType] = [.pdf]
    
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        if let fileData = configuration.file.regularFileContents {
            data = fileData
        } else {
            data = Data()
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
