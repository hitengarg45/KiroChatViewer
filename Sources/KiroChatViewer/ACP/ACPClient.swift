import Foundation
import Combine

enum ACPEvent {
    case chunk(String)
    case toolCall(name: String, status: String)
    case turnEnd
    case error(String)
    case permissionRequest(id: Int, toolName: String, args: String)
}

enum ACPState: Equatable {
    case disconnected, connecting, ready, chatting
}

class ACPClient: ObservableObject, ACPProviding {
    @Published var state: ACPState = .disconnected
    @Published var sessionId: String?
    
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var requestId = 0
    
    private let eventSubject = PassthroughSubject<ACPEvent, Never>()
    var events: AnyPublisher<ACPEvent, Never> { eventSubject.eraseToAnyPublisher() }
    
    private func nextId() -> Int { requestId += 1; return requestId }
    
    private func findKiroCli() -> String? {
        [NSHomeDirectory() + "/.toolbox/bin/kiro-cli",
         "/opt/homebrew/bin/kiro-cli",
         "/usr/local/bin/kiro-cli"
        ].first { FileManager.default.fileExists(atPath: $0) }
    }
    
    private func log(_ msg: String) {
        AppLogger.acp.info("\(msg)")
    }
    
    // MARK: - Connect
    
    func connect(cwd: String) {
        guard let path = findKiroCli() else {
            self.log("ACP: kiro-cli not found")
            eventSubject.send(.error("kiro-cli not found"))
            return
        }
        
        disconnect()
        state = .connecting
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = ["acp"]
        // Enable debug logging
        proc.environment = ProcessInfo.processInfo.environment
        
        let inPipe = Pipe()
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        
        self.process = proc
        self.stdinHandle = inPipe.fileHandleForWriting
        
        // Read stdout — read 1 byte at a time to avoid blocking on partial buffers
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fh = outPipe.fileHandleForReading
            var lineBuffer = Data()
            
            while true {
                let byte = fh.readData(ofLength: 1)
                if byte.isEmpty { break } // EOF
                
                if byte[byte.startIndex] == UInt8(ascii: "\n") {
                    guard let line = String(data: lineBuffer, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                          !line.isEmpty,
                          let jsonData = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                    else {
                        lineBuffer = Data()
                        continue
                    }
                    lineBuffer = Data()
                    DispatchQueue.main.async { self?.processMessage(json) }
                } else {
                    lineBuffer.append(byte)
                }
            }
            self?.log("ACP: stdout reader exited")
        }
        
        // Read stderr
        DispatchQueue.global(qos: .utility).async { [weak self] in
            while true {
                let data = errPipe.fileHandleForReading.readData(ofLength: 4096)
                if data.isEmpty { break }
                if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                    AppLogger.acp.error("ACP STDERR: \(str.prefix(500))")
                    if str.contains("Parse error") || str.contains("missing field") {
                        DispatchQueue.main.async {
                            self?.eventSubject.send(.error(str.components(separatedBy: "\"error\":").last?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Parse error"))
                        }
                    }
                }
            }
        }
        
        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.state = .disconnected
                self?.sessionId = nil
                AppLogger.acp.info("ACP: process terminated")
            }
        }
        
        do {
            try proc.run()
            self.log("ACP: process started, sending initialize")
            
            // Step 1: Initialize — session/new will be sent after init response
            self.pendingCwd = cwd
            send([
                "jsonrpc": "2.0",
                "id": nextId(),
                "method": "initialize",
                "params": [
                    "protocolVersion": 1,
                    "clientCapabilities": [String: Any](),
                    "clientInfo": ["name": "KiroChatViewer", "version": "3.6.0"]
                ] as [String: Any]
            ])
        } catch {
            self.log("ACP: failed to start: \(error.localizedDescription)")
            state = .disconnected
            eventSubject.send(.error("Failed to start kiro-cli: \(error.localizedDescription)"))
        }
    }
    
    private var pendingCwd = ""
    
    // MARK: - Prompt
    
    func prompt(text: String) {
        guard let sid = sessionId else {
            self.log("ACP: no session for prompt")
            return
        }
        state = .chatting
        let promptId = nextId()
        self.log("ACP: sending prompt id=\(promptId)")
        send([
            "jsonrpc": "2.0",
            "id": promptId,
            "method": "session/prompt",
            "params": [
                "sessionId": sid,
                "prompt": [["type": "text", "text": text]]
            ] as [String: Any]
        ])
    }
    
    func cancel() {
        guard let sid = sessionId else { return }
        send(["jsonrpc": "2.0", "method": "session/cancel", "params": ["sessionId": sid]])
    }
    
    func respondPermission(requestId: Int, allow: Bool) {
        send([
            "jsonrpc": "2.0",
            "id": requestId,
            "result": ["allowed": allow]
        ])
        log("ACP: permission response id=\(requestId) allowed=\(allow)")
    }
    
    func disconnect() {
        process?.terminate()
        process = nil
        stdinHandle = nil
        state = .disconnected
        sessionId = nil
        requestId = 0
    }
    
    // MARK: - Send
    
    private func send(_ msg: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: msg),
              var str = String(data: data, encoding: .utf8) else {
            self.log("ACP: failed to serialize message")
            return
        }
        str += "\n"
        guard let writeData = str.data(using: .utf8) else { return }
        stdinHandle?.write(writeData)
        self.log("ACP SEND: \(msg["method"] as? String ?? "?") id=\(msg["id"] as? Int ?? -1)")
    }
    
    // MARK: - Process Messages
    
    private func processMessage(_ json: [String: Any]) {
        let method = json["method"] as? String
        let id = json["id"] as? Int
        
        let hasResult = json["result"] != nil
        let hasError = json["error"] != nil
        self.log("ACP RECV: method=\(method ?? "nil") id=\(id ?? -1) result=\(hasResult) error=\(hasError)")
        
        // Response with result
        if let result = json["result"] as? [String: Any] {
            
            // Initialize response — has agentInfo
            if result["agentInfo"] != nil {
                self.log("ACP: initialized, sending session/new")
                // Now create session
                send([
                    "jsonrpc": "2.0",
                    "id": nextId(),
                    "method": "session/new",
                    "params": [
                        "cwd": pendingCwd,
                        "mcpServers": [Any]()
                    ] as [String: Any]
                ])
                return
            }
            
            // Session new response — has sessionId
            if let sid = result["sessionId"] as? String {
                sessionId = sid
                state = .ready
                self.log("ACP: session ready \(sid)")
                return
            }
            
            // Prompt response — has stopReason (turn complete)
            if let stopReason = result["stopReason"] as? String {
                self.log("ACP: turn ended, reason=\(stopReason)")
                state = .ready
                eventSubject.send(.turnEnd)
                return
            }
            
            self.log("ACP: unhandled result keys=\(Array(result.keys).prefix(5))")
            return
        }
        
        // Error response
        if let error = json["error"] as? [String: Any] {
            let msg = error["message"] as? String ?? "Unknown error"
            self.log("ACP ERROR: \(msg)")
            eventSubject.send(.error(msg))
            if state == .chatting { state = .ready }
            return
        }
        
        // Notification — session/update
        if method == "session/update",
           let params = json["params"] as? [String: Any],
           let update = params["update"] as? [String: Any] {
            
            let sessionUpdate = update["sessionUpdate"] as? String ?? ""
            log("ACP UPDATE: sessionUpdate=\(sessionUpdate) keys=\(Array(update.keys))")
            
            switch sessionUpdate {
            case "agent_message_chunk":
                let content = update["content"] as? [String: Any]
                let text = content?["text"] as? String ?? ""
                if !text.isEmpty {
                    eventSubject.send(.chunk(text))
                }
                
            case "tool_call":
                let name = update["title"] as? String ?? update["name"] as? String ?? "tool"
                let status = update["status"] as? String ?? ""
                eventSubject.send(.toolCall(name: name, status: status))
                
            case "tool_call_update":
                let name = update["title"] as? String ?? "tool"
                let status = update["status"] as? String ?? ""
                eventSubject.send(.toolCall(name: name, status: status))
                
            default:
                self.log("ACP: update type=\(sessionUpdate)")
            }
            return
        }
        
        // Other notifications (kiro extensions) — ignore silently
        if method?.hasPrefix("_kiro") == true || method?.hasPrefix("_session") == true {
            return
        }
        
        // session/request_permission — agent asking client to approve a tool
        if method == "session/request_permission",
           let reqId = json["id"] as? Int,
           let params = json["params"] as? [String: Any] {
            let toolName = params["toolName"] as? String ?? "unknown tool"
            var argsStr = ""
            if let args = params["arguments"] as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: args, options: [.prettyPrinted]),
               let str = String(data: data, encoding: .utf8) {
                argsStr = str
            }
            log("ACP: permission request id=\(reqId) tool=\(toolName)")
            eventSubject.send(.permissionRequest(id: reqId, toolName: toolName, args: argsStr))
            return
        }
        
        if method != nil {
            self.log("ACP: unhandled notification \(method!)")
        }
    }
}
