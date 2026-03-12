import Foundation
import os.log

struct AppLogger {
    private static let subsystem = "com.kiro.chatviewer"
    static let db = Logger(subsystem: subsystem, category: "database")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let perf = Logger(subsystem: subsystem, category: "performance")
    static let acp = Logger(subsystem: subsystem, category: "acp")
}
