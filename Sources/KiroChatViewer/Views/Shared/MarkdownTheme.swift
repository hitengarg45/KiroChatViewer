import SwiftUI
import MarkdownUI
import Splash

extension MarkdownUI.Theme {
    static let kiro = MarkdownUI.Theme()
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
            ForegroundColor(.pink)
            BackgroundColor(.pink.opacity(0.15))
        }
        .codeBlock { configuration in
            SyntaxHighlightedCodeBlock(configuration: configuration)
        }
}

struct SyntaxHighlightedCodeBlock: View {
    let configuration: CodeBlockConfiguration
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @State private var showCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let lang = configuration.language {
                    Text(lang)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                if isHovering || showCopied {
                    Button {
                        copyToClipboard()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                            Text(showCopied ? "Copied" : "Copy")
                                .font(.caption2)
                        }
                        .foregroundStyle(showCopied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            
            ScrollView(.horizontal, showsIndicators: true) {
                Text(highlightedCode)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .onHover { isHovering = $0 }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(configuration.content, forType: .string)
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopied = false
        }
    }
    
    private var highlightedCode: AttributedString {
        let code = configuration.content
        let language = configuration.language?.lowercased()
        
        // Use Swift grammar for most languages (Splash only has Swift built-in)
        // For others, return plain text
        let highlighter = SyntaxHighlighter(format: AttributedStringOutputFormat(theme: splashTheme))
        
        if language == "swift" || language == "swiftui" {
            let nsAttr = highlighter.highlight(code)
            return AttributedString(nsAttr)
        } else {
            return AttributedString(code)
        }
    }
    
    private var splashTheme: Splash.Theme {
        colorScheme == .dark ? .sundellsColors(withFont: .init(size: 14)) : .sunset(withFont: .init(size: 14))
    }
}
