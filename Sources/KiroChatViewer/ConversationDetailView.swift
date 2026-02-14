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
        // Create attributed string
        let fullText = NSMutableAttributedString()
        
        let titleFont = NSFont.boldSystemFont(ofSize: 24)
        fullText.append(NSAttributedString(string: conversation.title + "\n\n", attributes: [.font: titleFont]))
        
        let metaFont = NSFont.systemFont(ofSize: 10)
        fullText.append(NSAttributedString(string: "Updated: \(conversation.updatedAt.formatted())\n\n", 
                                          attributes: [.font: metaFont, .foregroundColor: NSColor.gray]))
        
        let roleFont = NSFont.boldSystemFont(ofSize: 14)
        let bodyFont = NSFont.systemFont(ofSize: 11)
        
        for message in conversation.messages {
            let roleText = message.role == .user ? "You:\n" : "Kiro:\n"
            fullText.append(NSAttributedString(string: roleText, attributes: [.font: roleFont]))
            fullText.append(NSAttributedString(string: message.content + "\n\n", attributes: [.font: bodyFont]))
        }
        
        // Setup print info
        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: 612, height: 792)
        printInfo.topMargin = 50
        printInfo.bottomMargin = 50
        printInfo.leftMargin = 50
        printInfo.rightMargin = 50
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        
        let pageRect = NSRect(x: 0, y: 0, 
                             width: printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin,
                             height: printInfo.paperSize.height - printInfo.topMargin - printInfo.bottomMargin)
        
        // Create text view
        let textView = NSTextView(frame: pageRect)
        textView.textStorage?.setAttributedString(fullText)
        
        // Create print operation
        let printOp = NSPrintOperation(view: textView, printInfo: printInfo)
        printOp.showsPrintPanel = false
        printOp.showsProgressPanel = false
        
        // Generate PDF to temp file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        printOp.pdfPanel.options = []
        
        // Save to file then read back
        if printOp.run() {
            printOp.deliverResult()
        }
        
        // Use PDFDocument for proper pagination
        let pdfDoc = PDFDocument()
        var currentPage = 0
        let pageHeight = pageRect.height
        var yOffset: CGFloat = 0
        
        while yOffset < textView.layoutManager!.usedRect(for: textView.textContainer!).height {
            let pageData = textView.dataWithPDF(inside: NSRect(x: 0, y: yOffset, width: pageRect.width, height: pageHeight))
            if let page = PDFPage(image: NSImage(data: pageData)!) {
                pdfDoc.insert(page, at: currentPage)
                currentPage += 1
            }
            yOffset += pageHeight
        }
        
        return pdfDoc.dataRepresentation()
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
