import Foundation
import os.log

// MARK: - Log Entry

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: String
    let level: String
    let message: String
}

// MARK: - Log Buffer

final class LogBuffer: ObservableObject {
    static let shared = LogBuffer()
    
    @Published private(set) var entries: [LogEntry] = []
    private let lock = NSLock()
    private let maxEntries = 2000
    
    // File logging
    private let logDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/KiroChatViewer/logs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    private var fileHandle: FileHandle?
    private var currentLogSize: UInt64 = 0
    private let maxFileSize: UInt64 = 5 * 1024 * 1024 // 5 MB
    private let maxLogFiles = 3
    
    private static let fileDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()
    
    init() { openLogFile() }
    
    deinit { fileHandle?.closeFile() }
    
    func append(category: String, level: String, message: String) {
        let entry = LogEntry(timestamp: Date(), category: category, level: level, message: message)
        
        // In-memory buffer (main thread for @Published)
        DispatchQueue.main.async {
            self.lock.lock()
            self.entries.append(entry)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
            self.lock.unlock()
        }
        
        // File logging (background)
        let line = "\(Self.fileDateFormatter.string(from: entry.timestamp)) [\(level)] [\(category)] \(message)\n"
        if let data = line.data(using: .utf8) {
            writeToFile(data)
        }
    }
    
    func clear() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }
    
    var currentLogPath: URL { logDir.appendingPathComponent("app.log") }
    
    // MARK: - File Operations
    
    private func openLogFile() {
        let path = currentLogPath
        if !FileManager.default.fileExists(atPath: path.path) {
            FileManager.default.createFile(atPath: path.path, contents: nil)
        }
        fileHandle = try? FileHandle(forWritingTo: path)
        fileHandle?.seekToEndOfFile()
        currentLogSize = fileHandle?.offsetInFile ?? 0
    }
    
    private func writeToFile(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        
        fileHandle?.write(data)
        currentLogSize += UInt64(data.count)
        
        if currentLogSize >= maxFileSize {
            rotateLogFiles()
        }
    }
    
    private func rotateLogFiles() {
        fileHandle?.closeFile()
        fileHandle = nil
        
        // Shift existing rotated files: app.2.log → app.3.log, app.1.log → app.2.log
        for i in stride(from: maxLogFiles - 1, through: 1, by: -1) {
            let src = logDir.appendingPathComponent("app.\(i).log")
            let dst = logDir.appendingPathComponent("app.\(i + 1).log")
            try? FileManager.default.removeItem(at: dst)
            try? FileManager.default.moveItem(at: src, to: dst)
        }
        
        // Current → app.1.log
        let rotated = logDir.appendingPathComponent("app.1.log")
        try? FileManager.default.moveItem(at: currentLogPath, to: rotated)
        
        // Delete oldest if over limit
        let oldest = logDir.appendingPathComponent("app.\(maxLogFiles).log")
        try? FileManager.default.removeItem(at: oldest)
        
        // Start fresh
        openLogFile()
    }
}

// MARK: - App Logger

struct AppLogger {
    private static let subsystem = "com.kiro.chatviewer"
    
    static let db = CategoryLogger(subsystem: subsystem, category: "database")
    static let ui = CategoryLogger(subsystem: subsystem, category: "ui")
    static let perf = CategoryLogger(subsystem: subsystem, category: "performance")
    static let acp = CategoryLogger(subsystem: subsystem, category: "acp")
}

/// Logger that writes to both os.log and in-memory LogBuffer.
struct CategoryLogger {
    private let logger: Logger
    let category: String
    
    init(subsystem: String, category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
        self.category = category
    }
    
    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        LogBuffer.shared.append(category: category, level: "DEBUG", message: message)
    }
    
    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        LogBuffer.shared.append(category: category, level: "INFO", message: message)
    }
    
    func notice(_ message: String) {
        logger.notice("\(message, privacy: .public)")
        LogBuffer.shared.append(category: category, level: "NOTICE", message: message)
    }
    
    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        LogBuffer.shared.append(category: category, level: "ERROR", message: message)
    }
}
