import SwiftUI
import Combine

class LiveChatViewModel: ObservableObject {
    @Published var messages: [LiveMessage] = []
    @Published var inputText = ""
    @Published var isConnected = false
    @Published var isStreaming = false
    @Published var currentModel = "auto"
    @Published var workingDirectory = NSHomeDirectory()
    @Published var error: String?
    @Published var pendingPermission: (id: String, toolName: String, options: [(id: String, name: String)])?
    @Published var contextUsage: Double = 0
    @Published var trustAllTools = false
    
    let client = ACPClient()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        client.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                let wasConnected = self.isConnected
                self.isConnected = state == .ready || state == .chatting
                self.isStreaming = state == .chatting
                // Notify if connection dropped unexpectedly
                if wasConnected && state == .disconnected {
                    self.error = "Connection to Kiro lost"
                    AppLogger.ui.error("LiveChat: connection dropped")
                }
            }
            .store(in: &cancellables)
        
        client.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in self?.handleEvent(event) }
            .store(in: &cancellables)
    }
    
    func connect() {
        AppLogger.ui.info("LiveChat: connecting to \(self.workingDirectory)")
        client.connect(cwd: workingDirectory)
    }
    
    func setModel(_ model: String) {
        currentModel = model
        if isConnected {
            client.setModel(model)
        }
    }
    
    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        AppLogger.ui.info("LiveChat: sending prompt (\(text.count) chars)")
        messages.append(LiveMessage(role: .user, content: text))
        messages.append(LiveMessage(role: .assistant, content: "", isStreaming: true))
        inputText = ""
        client.prompt(text: text)
    }
    
    func stop() {
        AppLogger.ui.info("LiveChat: cancelling")
        client.cancel()
        if let idx = messages.indices.last, messages[idx].isStreaming {
            messages[idx].isStreaming = false
        }
    }
    
    func disconnect() {
        AppLogger.ui.info("LiveChat: disconnecting")
        client.disconnect()
        messages.removeAll()
        pendingPermission = nil
    }
    
    func respondPermission(optionId: String) {
        guard let perm = pendingPermission else { return }
        AppLogger.ui.info("LiveChat: permission \(optionId) for \(perm.toolName)")
        client.respondPermission(requestId: perm.id, optionId: optionId)
        pendingPermission = nil
    }
    
    private func handleEvent(_ event: ACPEvent) {
        switch event {
        case .chunk(let text):
            if let idx = messages.indices.last, messages[idx].role == .assistant {
                messages[idx].content += text
            }
            
        case .toolCall(let name, let status):
            if let idx = messages.indices.last, messages[idx].role == .assistant && messages[idx].isStreaming {
                let tool = LiveMessage(role: .tool, content: "", toolName: name, toolStatus: status)
                messages.insert(tool, at: idx)
            }
            
        case .turnEnd:
            if let idx = messages.indices.last, messages[idx].isStreaming {
                messages[idx].isStreaming = false
            }
            AppLogger.ui.info("LiveChat: turn ended, \(self.messages.count) messages")
            
        case .error(let msg):
            error = msg
            AppLogger.ui.error("LiveChat: error — \(msg)")
            if let idx = messages.indices.last, messages[idx].isStreaming {
                messages[idx].isStreaming = false
                messages[idx].content += "\n\n⚠️ Error: \(msg)"
            }
            
        case .permissionRequest(let id, let toolName, let options):
            AppLogger.ui.info("LiveChat: permission request for \(toolName)")
            if trustAllTools {
                let allowOpt = options.first(where: { $0.id.contains("allow") })?.id ?? "allow_once"
                AppLogger.ui.info("LiveChat: auto-approved \(toolName) (autopilot)")
                client.respondPermission(requestId: id, optionId: allowOpt)
            } else {
                pendingPermission = (id: id, toolName: toolName, options: options)
            }
            
        case .contextUpdate(let pct):
            contextUsage = pct
        }
    }
}
