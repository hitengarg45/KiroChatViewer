import Foundation
import Combine

enum ACPEvent {
    case chunk(String)
    case toolCall(name: String, status: String)
    case turnEnd
    case error(String)
}

enum ACPState: Equatable {
    case disconnected, connecting, ready, chatting
}

class ACPClient: ObservableObject {
    @Published var state: ACPState = .disconnected
    @Published var sessionId: String?
    
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var requestId = 0
    private var buffer = ""
    
    private let eventSubject = PassthroughSubject<ACPEvent, Never>()
    var events: AnyPublisher<ACPEvent, Never> { eventSubject.eraseToAnyPublisher() }
    
    private func nextId() -> Int { requestId += 1; return requestId }
    
    private func findKiroCli() -> String? {
        [NSHomeDirectory() + "/.toolbox/bin/kiro-cli",
         "/opt/homebrew/bin/kiro-cli",
         "/usr/local/bin/kiro-cli"
        ].first { FileManager.default.fileExists(atPath: $0) }
    }
    
    // MARK: - Connect
    
    func connect(cwd: String, model: String = "qwen3-coder-480b") {
        guard let path = findKiroCli() else {
            AppLogger.db.error("kiro-cli not found")
            return
        }
        
        disconnect()
        state = .connecting
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = ["acp"]
        
        let inPipe = Pipe()
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        
        self.process = proc
        self.stdinHandle = inPipe.fileHandleForWriting
        
        // Read stdout on background thread — line buffered
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let handle = outPipe.fileHandleForReading
            var buf = Data()
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }
                buf.append(chunk)
                
                // Process complete lines
                while let newline = buf.firstIndex(of: UInt8(ascii: "\n")) {
                    let lineData = buf[buf.startIndex..<newline]
                    buf = Data(buf[(newline + 1)...])
                    
                    guard let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespaces),
                          !line.isEmpty else { continue }
                    
                    AppLogger.db.info("ACP RECV: \(String(line.prefix(200)))")
                    
                    guard let data = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                    
                    DispatchQueue.main.async { self?.processMessage(json) }
                }
            }
            AppLogger.db.info("ACP stdout closed")
        }
        
        // Log stderr
        DispatchQueue.global(qos: .utility).async {
            let handle = errPipe.fileHandleForReading
            while true {
                let data = handle.availableData
                if data.isEmpty { break }
                if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                    AppLogger.db.error("ACP STDERR: \(str.prefix(300))")
                }
            }
        }
        
        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.state = .disconnected
                self?.sessionId = nil
            }
        }
        
        do {
            try proc.run()
            AppLogger.db.info("ACP process started")
            
            // Step 1: Initialize
            send([
                "jsonrpc": "2.0",
                "id": nextId(),
                "method": "initialize",
                "params": [
                    "protocolVersion": "1",
                    "clientCapabilities": [String: Any](),
                    "clientInfo": ["name": "KiroChatViewer", "version": "3.5.0"]
                ] as [String: Any]
            ])
            
            // Step 2: Create session (sent immediately — responses are queued)
            send([
                "jsonrpc": "2.0",
                "id": nextId(),
                "method": "session/new",
                "params": [
                    "cwd": cwd,
                    "mcpServers": [Any]()
                ] as [String: Any]
            ])
            
        } catch {
            AppLogger.db.error("Failed to start ACP: \(error.localizedDescription)")
            state = .disconnected
        }
    }
    
    // MARK: - Prompt
    
    func prompt(text: String) {
        guard let sid = sessionId else {
            AppLogger.db.error("No session ID for prompt")
            return
        }
        state = .chatting
        send([
            "jsonrpc": "2.0",
            "id": nextId(),
            "method": "prompt",
            "params": [
                "sessionId": sid,
                "prompt": [["kind": "text", "data": text]]
            ] as [String: Any]
        ])
    }
    
    func cancel() {
        guard let sid = sessionId else { return }
        send([
            "jsonrpc": "2.0",
            "method": "session/cancel",
            "params": ["sessionId": sid]
        ])
    }
    
    func disconnect() {
        process?.terminate()
        process = nil
        stdinHandle = nil
        state = .disconnected
        sessionId = nil
    }
    
    // MARK: - Send
    
    private func send(_ msg: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: msg),
              var str = String(data: data, encoding: .utf8) else { return }
        str += "\n"
        stdinHandle?.write(str.data(using: .utf8)!)
        AppLogger.db.info("ACP SEND: \(msg["method"] as? String ?? "?")")
    }
    
    // MARK: - Process Messages
    
    private func processMessage(_ json: [String: Any]) {
        // Response with result
        if let result = json["result"] as? [String: Any] {
            // Session new → has sessionId
            if let sid = result["sessionId"] as? String {
                self.sessionId = sid
                self.state = .ready
                AppLogger.db.info("ACP session ready: \(sid)")
                return
            }
            // Initialize → has serverInfo or agentInfo
            if result["serverInfo"] != nil || result["agentInfo"] != nil {
                AppLogger.db.info("ACP initialized")
                return
            }
        }
        
        // Error response
        if let error = json["error"] as? [String: Any] {
            let msg = error["message"] as? String ?? "Unknown error"
            AppLogger.db.error("ACP error: \(msg)")
            eventSubject.send(.error(msg))
            return
        }
        
        // Notification — session/update
        if let method = json["method"] as? String, method == "session/update",
           let params = json["params"] as? [String: Any],
           let update = params["update"] as? [String: Any] {
            
            let sessionUpdate = update["sessionUpdate"] as? String ?? update["kind"] as? String ?? ""
            
            switch sessionUpdate {
            case "agent_message_chunk", "AgentMessageChunk":
                let text = update["text"] as? String
                    ?? (update["content"] as? [String: Any])?["text"] as? String
                    ?? ""
                if !text.isEmpty {
                    eventSubject.send(.chunk(text))
                }
                
            case "tool_use", "ToolCall":
                let name = update["name"] as? String ?? update["toolName"] as? String ?? "tool"
                let status = update["status"] as? String ?? ""
                eventSubject.send(.toolCall(name: name, status: status))
                
            case "end_turn", "TurnEnd":
                state = .ready
                eventSubject.send(.turnEnd)
                
            default:
                AppLogger.db.info("ACP update: \(sessionUpdate)")
            }
        }
    }
}
