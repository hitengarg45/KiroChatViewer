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
        // Observe client state
        client.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.isConnected = state == .ready || state == .chatting
                self?.isStreaming = state == .chatting
            }
            .store(in: &cancellables)
        
        // Observe events
        client.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in self?.handleEvent(event) }
            .store(in: &cancellables)
    }
    
    func connect() {
        client.connect(cwd: workingDirectory)
    }
    
    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        messages.append(LiveMessage(role: "user", content: text))
        messages.append(LiveMessage(role: "assistant", content: "", isStreaming: true))
        inputText = ""
        client.prompt(text: text)
    }
    
    func stop() {
        client.cancel()
        if let idx = messages.indices.last, messages[idx].isStreaming {
            messages[idx].isStreaming = false
        }
    }
    
    func disconnect() {
        client.disconnect()
        messages.removeAll()
    }
    
    private func handleEvent(_ event: ACPEvent) {
        switch event {
        case .chunk(let text):
            if let idx = messages.indices.last, messages[idx].role == "assistant" {
                messages[idx].content += text
            }
            
        case .toolCall(let name, let status):
            // Insert tool message before the current assistant message
            if let idx = messages.indices.last, messages[idx].role == "assistant" && messages[idx].isStreaming {
                let tool = LiveMessage(role: "tool", content: "", toolName: name, toolStatus: status)
                messages.insert(tool, at: idx)
            }
            
        case .turnEnd:
            if let idx = messages.indices.last, messages[idx].isStreaming {
                messages[idx].isStreaming = false
            }
            
        case .error(let msg):
            error = msg
            if let idx = messages.indices.last, messages[idx].isStreaming {
                messages[idx].isStreaming = false
                messages[idx].content += "\n\n⚠️ Error: \(msg)"
            }
        }
    }
}

