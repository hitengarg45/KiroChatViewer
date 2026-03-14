import SwiftUI
import SwiftTerm

/// Wraps an existing LocalProcessTerminalView for display in SwiftUI.
/// The terminal view is managed by TerminalSessionManager, not created here.
struct EmbeddedTerminalView: NSViewRepresentable {
    let terminalView: LocalProcessTerminalView
    
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        terminalView
    }
    
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}
