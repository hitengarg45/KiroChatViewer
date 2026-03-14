import SwiftUI
import SwiftTerm

/// Manages embedded terminal sessions across conversation switches.
/// Keeps sessions alive when switching, cleans up on explicit close.
class TerminalSessionManager: ObservableObject {
    static let shared = TerminalSessionManager()
    
    /// Active terminal views keyed by conversation ID
    @Published private(set) var activeSessions: Set<String> = []
    
    /// Minimized terminals (header only, session still alive)
    @Published var minimizedSessions: Set<String> = []
    
    /// The actual terminal views — kept alive across conversation switches
    private var terminalViews: [String: LocalProcessTerminalView] = [:]
    
    func isActive(_ conversationId: String) -> Bool {
        activeSessions.contains(conversationId)
    }
    
    func isMinimized(_ conversationId: String) -> Bool {
        minimizedSessions.contains(conversationId)
    }
    
    func toggleMinimize(_ conversationId: String) {
        if minimizedSessions.contains(conversationId) {
            minimizedSessions.remove(conversationId)
        } else {
            minimizedSessions.insert(conversationId)
        }
    }
    
    /// Start a terminal session for a conversation
    func startSession(id: String, directory: String, command: String) {
        guard !activeSessions.contains(id) else { return }
        
        let tv = LocalProcessTerminalView(frame: .zero)
        let palette = TerminalPalette.colors(for: ThemeManager.shared.terminalStyle)
        tv.nativeBackgroundColor = NSColor(palette.bg)
        tv.nativeForegroundColor = NSColor(palette.fg)
        tv.font = NSFont.monospacedSystemFont(ofSize: CGFloat(ThemeManager.shared.messageFontSize), weight: .regular)
        
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        let shell = env["SHELL"] ?? "/bin/zsh"
        let envArray = env.map { "\($0.key)=\($0.value)" }
        
        tv.startProcess(executable: shell, args: ["-l"], environment: envArray, execName: shell)
        
        let escapedDir = "'" + directory.replacingOccurrences(of: "'", with: "'\\''") + "'"
        if command.isEmpty {
            tv.send(txt: "cd \(escapedDir) && clear\n")
        } else {
            tv.send(txt: "cd \(escapedDir) && \(command)\n")
        }
        
        terminalViews[id] = tv
        activeSessions.insert(id)
        AppLogger.ui.info("Terminal session started for \(id)")
    }
    
    /// Close and clean up a terminal session
    func closeSession(id: String) {
        if let tv = terminalViews[id], tv.process != nil, tv.process.shellPid > 0 {
            kill(tv.process.shellPid, SIGHUP)
        }
        terminalViews.removeValue(forKey: id)
        activeSessions.remove(id)
        minimizedSessions.remove(id)
        AppLogger.ui.info("Terminal session closed for \(id)")
    }
    
    /// Get the terminal view for a conversation (nil if no active session)
    func terminalView(for id: String) -> LocalProcessTerminalView? {
        terminalViews[id]
    }
    
    /// Update theme on all active terminals
    func applyTheme() {
        let palette = TerminalPalette.colors(for: ThemeManager.shared.terminalStyle)
        let fontSize = CGFloat(ThemeManager.shared.messageFontSize)
        for tv in terminalViews.values {
            tv.nativeBackgroundColor = NSColor(palette.bg)
            tv.nativeForegroundColor = NSColor(palette.fg)
            tv.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
    }
    
    /// Clean up all sessions (app quit)
    func closeAll() {
        for id in Array(activeSessions) {
            closeSession(id: id)
        }
    }
    
    deinit { closeAll() }
}
