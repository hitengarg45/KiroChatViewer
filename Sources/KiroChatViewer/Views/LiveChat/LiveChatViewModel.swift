import SwiftUI
import Combine

class LiveChatViewModel: ObservableObject {
    @Published var messages: [LiveMessage] = []
    @Published var inputText = ""
    @Published var isConnected = false
    @Published var isStreaming = false
    @Published var currentModel = "qwen3-coder-480b"
    @Published var workingDirectory = NSHomeDirectory()
    @Published var error: String?
    
    let client = ACPClient()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        client.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.isConnected = state == .ready || state == .chatting
                self?.isStreaming = state == .chatting
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
        }
    }
}
